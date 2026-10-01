# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule ZenflowsTest.Authz.ConcurrencyRevoke do
@moduledoc """
Revoking two different org.admin relationships of the same organization
at once used to be able to deadlock: before the fix, each transaction
locked its own target row FOR UPDATE in
`Zenflows.VF.AgentRelationship.Domain.multi_load/3` *before* reaching
the organization's advisory lock (taken only once
`Zenflows.Authz.Membership.multi_revoke/5`'s authorize step ran, which
also locks the acting person's own admin row FOR SHARE via
`Zenflows.Authz.Facts.admin_of/3`).  So e.g. alice revoking bob while
bob concurrently revokes alice could interleave as: T1 locks bob's row,
then the advisory lock, then waits FOR SHARE on alice's row (held
FOR UPDATE by T2); T2 locks alice's row, then waits on the advisory
lock (held by T1) -- a genuine circular wait, which Postgres detects
and kills one side with a 40P01 "deadlock detected" error, surfacing as
a raised exception instead of a domain-level `{:error, _}`.

The fix reorders `multi_load/3` to take the organization's advisory
lock *before* any row lock whenever the target is a system-role
relationship, so every transaction touching this org's system
relationships acquires locks in the same order and a cross-wait is
no longer possible: the second transaction simply blocks on the
single advisory lock until the first commits.

Two more interleavings used to deadlock the same way and are covered
below: a grant racing a revoke in the same organization
(`Membership.multi_grant/4` used to lock the granter's admin rows FOR
SHARE before taking the organization's advisory lock, the opposite
order of a revoke), and two admins revoking each other in two different
organizations (`Facts.admin_of` used to lock the actor's admin rows of
EVERY organization, so the two independent revokes could each hold a
row the other wanted).  Grants now take the advisory lock first, and
`Facts.admin_of/3` locks only the rows of the organizations a decision
actually looks at.

All tests here run real, separate Postgres connections outside the
Ecto sandbox (the sandbox would serialize both "connections" onto one
connection, which can neither block nor deadlock).
"""
use ExUnit.Case, async: false

import Ecto.Query

alias Ecto.Adapters.SQL.Sandbox
alias Zenflows.Authz.Roles
alias Zenflows.DB.Repo
alias Zenflows.VF.{AgentRelationship, AgentRelationship.Domain, Organization, Person}
alias ZenflowsTest.Help.Factory

setup do
	fixtures = Sandbox.unboxed_run(Repo, fn -> insert_org_with_admins!() end)

	on_exit(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			delete_fixtures!(fixtures)
			Repo.query!("TRUNCATE zf_permission_log")
		end)
	end)

	fixtures
end

test "a revoke that is still mid-transaction blocks a concurrent revoke of a different admin, it doesn't deadlock", c do
	# Task A: alice revokes bob, inside an explicit outer transaction we
	# keep open (so the locks `Domain.delete/2`'s own inner transaction
	# takes stay held) until the test tells it to commit.
	task_a = parked_task(fn -> Domain.delete(Factory.ctx(c.alice), c.bob_rel.id) end)

	try do
		assert_receive :locked, 2000

		# Task B: bob (while A is still mid-transaction, holding every lock
		# it took) tries to revoke alice.
		task_b = unboxed_task(fn -> Domain.delete(Factory.ctx(c.bob), c.alice_rel.id) end)

		# B must be blocked waiting on a lock A holds, not dead: a real
		# deadlock would make Postgres kill one side with a 40P01 error
		# (raised as an exception) well before this timeout, crashing the
		# task instead of leaving it merely pending.
		assert Task.yield(task_b, 300) == nil

		send(task_a.pid, :commit)

		assert {:ok, %AgentRelationship{revoked_at: %DateTime{}}} = Task.await(task_a, 2000)
		# By the time B's revoke of alice actually runs, A has already
		# committed bob's own revocation, so bob is no longer an active
		# admin and is denied -- not an exception, not a deadlock.
		assert {:error, :forbidden} = Task.await(task_b, 2000)
	after
		send(task_a.pid, :commit)
	end
end

test "many unsynchronized concurrent revoke races between two admins never raise", _c do
	# The test above pins A's signal to after `Domain.delete/2` has
	# already finished (and so already holds every lock it will ever
	# need), which makes B's wait deterministic but can't, by
	# construction, reproduce a genuine circular wait: A is never
	# itself blocked on something B holds. The actual bug needed real,
	# unsynchronized concurrency instead, where both sides can be
	# mid-acquisition at once. Running this same loop against the
	# pre-fix `multi_load/3` raises a `Postgrex.Error` ("deadlock
	# detected") in roughly half of the trials; against the fix, it
	# never does. Repeated, since any single pair of tasks may or may
	# not happen to race.
	for _ <- 1..15 do
		fx = Sandbox.unboxed_run(Repo, fn -> insert_org_with_admins!() end)

		try do
			task_a = rescuing_task(fn -> Domain.delete(Factory.ctx(fx.alice), fx.bob_rel.id) end)
			task_b = rescuing_task(fn -> Domain.delete(Factory.ctx(fx.bob), fx.alice_rel.id) end)

			ra = Task.await(task_a, 5000)
			rb = Task.await(task_b, 5000)

			refute match?({:raised, _}, ra), "task A raised: #{inspect(ra)}"
			refute match?({:raised, _}, rb), "task B raised: #{inspect(rb)}"
			# Whichever side's own admin status survives wins; the other is
			# denied because it is no longer an active admin by the time it
			# gets to check -- exactly one of each, every time.
			assert Enum.sort([outcome(ra), outcome(rb)]) == [:forbidden, :revoked]
		after
			Sandbox.unboxed_run(Repo, fn -> delete_fixtures!(fx) end)
		end
	end
end

test "a revoke that is still mid-transaction blocks a concurrent grant by the revoked admin, it doesn't deadlock", c do
	# A: alice revokes bob and keeps the transaction open.
	task_a = parked_task(fn -> Domain.delete(Factory.ctx(c.alice), c.bob_rel.id) end)

	try do
		assert_receive :locked, 2000

		# B: bob grants dave a role in the same organization.  The grant
		# takes the organization's advisory lock (held by A) before it
		# looks at bob's admin row, so it must simply wait.
		task_b = unboxed_task(fn -> grant(c.bob, c.dave, c.org) end)

		assert Task.yield(task_b, 300) == nil

		send(task_a.pid, :commit)

		assert {:ok, %AgentRelationship{revoked_at: %DateTime{}}} = Task.await(task_a, 2000)
		# bob was revoked before his grant got to decide.
		assert {:error, :forbidden} = Task.await(task_b, 2000)
	after
		send(task_a.pid, :commit)
	end

	assert Sandbox.unboxed_run(Repo, fn ->
		Repo.exists?(from r in AgentRelationship, where: r.subject_id == ^c.dave.id)
	end) == false
end

test "many unsynchronized grant/revoke races in one organization never raise", _c do
	# Against the pre-fix `Membership.multi_grant/4` (admin row FOR SHARE
	# first, advisory lock second), this raised 40P01 in most trials.
	for _ <- 1..15 do
		fx = Sandbox.unboxed_run(Repo, fn -> insert_org_with_admins!() end)

		try do
			task_a = rescuing_task(fn -> Domain.delete(Factory.ctx(fx.alice), fx.bob_rel.id) end)
			task_b = rescuing_task(fn -> grant(fx.bob, fx.dave, fx.org) end)

			ra = Task.await(task_a, 5000)
			rb = Task.await(task_b, 5000)

			refute match?({:raised, _}, ra), "revoke raised: #{inspect(ra)}"
			refute match?({:raised, _}, rb), "grant raised: #{inspect(rb)}"
			# alice stays an admin, and there are three, so her revoke always
			# goes through; bob's grant succeeds only if it ran first.
			assert {:ok, %AgentRelationship{revoked_at: %DateTime{}}} = ra
			assert match?({:ok, %AgentRelationship{revoked_at: nil}}, rb)
				or rb == {:error, :forbidden}, "unexpected grant result: #{inspect(rb)}"
		after
			Sandbox.unboxed_run(Repo, fn -> delete_fixtures!(fx) end)
		end
	end
end

test "many unsynchronized mutual revokes across two organizations never raise and both succeed", _c do
	# alice and bob are admins of both X and Y.  alice revokes bob in X
	# while bob revokes alice in Y: independent organizations, so both
	# must succeed.  Before `Facts.admin_of/3` was scoped, each side
	# locked its actor's admin rows in BOTH orgs FOR SHARE, and each held
	# FOR UPDATE the very row the other wanted -- a deadlock.
	for _ <- 1..15 do
		fx = Sandbox.unboxed_run(Repo, fn -> insert_two_orgs!() end)

		try do
			task_a = rescuing_task(fn -> Domain.delete(Factory.ctx(fx.alice), fx.bob_x.id) end)
			task_b = rescuing_task(fn -> Domain.delete(Factory.ctx(fx.bob), fx.alice_y.id) end)

			ra = Task.await(task_a, 5000)
			rb = Task.await(task_b, 5000)

			refute match?({:raised, _}, ra), "task A raised: #{inspect(ra)}"
			refute match?({:raised, _}, rb), "task B raised: #{inspect(rb)}"
			assert outcome(ra) == :revoked
			assert outcome(rb) == :revoked
		after
			Sandbox.unboxed_run(Repo, fn -> delete_fixtures!(fx) end)
		end
	end
end

defp outcome({:ok, %AgentRelationship{revoked_at: %DateTime{}}}), do: :revoked
defp outcome({:error, :forbidden}), do: :forbidden

# Runs `fun` on its own unboxed connection inside an outer transaction,
# sends `:locked` to the test once `fun` returned, and keeps the
# transaction (and every lock taken) open until it receives `:commit`.
defp parked_task(fun) do
	test_pid = self()
	Task.async(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			{:ok, result} = Repo.transaction(fn ->
				result = fun.()
				send(test_pid, :locked)
				receive do
					:commit -> :ok
				end
				result
			end)
			result
		end)
	end)
end

defp unboxed_task(fun) do
	Task.async(fn -> Sandbox.unboxed_run(Repo, fun) end)
end

defp rescuing_task(fun) do
	unboxed_task(fn ->
		try do
			fun.()
		rescue
			e -> {:raised, e}
		end
	end)
end

defp grant(granter, per, org) do
	Domain.create(Factory.ctx(granter), %{
		subject_id: per.id,
		object_id: org.id,
		relationship_id: Roles.id!(Repo, "org.member"),
	})
end

defp insert_person!() do
	Repo.insert!(Person.changeset(%{
		name: Factory.str("some name"), user: Factory.str("some user"),
		email: "#{Factory.str("user")}@example.com"}))
end

defp insert_org!() do
	Repo.insert!(Organization.changeset(%Organization{}, %{name: Factory.str("some name")}))
end

defp insert_admin!(per, org) do
	Repo.insert!(%AgentRelationship{subject_id: per.id, object_id: org.id,
		in_scope_of_id: org.id, relationship_id: Roles.id!(Repo, "org.admin")})
end

defp insert_org_with_admins!() do
	alice = insert_person!()
	bob = insert_person!()
	carol = insert_person!()
	dave = insert_person!()
	org = insert_org!()
	%{alice: alice, bob: bob, carol: carol, dave: dave, org: org,
		alice_rel: insert_admin!(alice, org),
		bob_rel: insert_admin!(bob, org),
		carol_rel: insert_admin!(carol, org),
		persons: [alice, bob, carol, dave], orgs: [org]}
end

defp insert_two_orgs!() do
	alice = insert_person!()
	bob = insert_person!()
	x = insert_org!()
	y = insert_org!()
	%{alice: alice, bob: bob,
		alice_x: insert_admin!(alice, x), bob_x: insert_admin!(bob, x),
		alice_y: insert_admin!(alice, y), bob_y: insert_admin!(bob, y),
		persons: [alice, bob], orgs: [x, y]}
end

defp delete_fixtures!(fixtures) do
	org_ids = Enum.map(fixtures.orgs, & &1.id)
	Repo.delete_all(from r in AgentRelationship, where: r.object_id in ^org_ids)
	Enum.each(fixtures.persons, &Repo.delete!/1)
	Enum.each(fixtures.orgs, &Repo.delete!/1)
end
end
