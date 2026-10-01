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
`Zenflows.Authz.Facts.admin_of/2`).  So e.g. alice revoking bob while
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

Both tests here run real, separate Postgres connections outside the
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
			delete_org!(fixtures)
			Repo.query!("TRUNCATE zf_permission_log")
		end)
	end)

	fixtures
end

test "a revoke that is still mid-transaction blocks a concurrent revoke of a different admin, it doesn't deadlock", c do
	test_pid = self()

	# Task A: alice revokes bob, inside an explicit outer transaction we
	# keep open (so the locks `Domain.delete/2`'s own inner transaction
	# takes stay held) until the test tells it to commit.
	task_a = Task.async(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			{:ok, result} = Repo.transaction(fn ->
				result = Domain.delete(Factory.ctx(c.alice), c.bob_rel.id)
				send(test_pid, :locked)
				receive do
					:commit -> :ok
				end
				result
			end)
			result
		end)
	end)

	assert_receive :locked, 2000

	# Task B: bob (while A is still mid-transaction, holding every lock
	# it took) tries to revoke alice.
	task_b = Task.async(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			Domain.delete(Factory.ctx(c.bob), c.alice_rel.id)
		end)
	end)

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

		task_a = Task.async(fn ->
			Sandbox.unboxed_run(Repo, fn ->
				try do
					Domain.delete(Factory.ctx(fx.alice), fx.bob_rel.id)
				rescue
					e -> {:raised, e}
				end
			end)
		end)

		task_b = Task.async(fn ->
			Sandbox.unboxed_run(Repo, fn ->
				try do
					Domain.delete(Factory.ctx(fx.bob), fx.alice_rel.id)
				rescue
					e -> {:raised, e}
				end
			end)
		end)

		ra = Task.await(task_a, 5000)
		rb = Task.await(task_b, 5000)

		refute match?({:raised, _}, ra), "task A raised: #{inspect(ra)}"
		refute match?({:raised, _}, rb), "task B raised: #{inspect(rb)}"
		# Whichever side's own admin status survives wins; the other is
		# denied because it is no longer an active admin by the time it
		# gets to check -- exactly one of each, every time.
		assert Enum.sort([outcome(ra), outcome(rb)]) == [:forbidden, :revoked]

		Sandbox.unboxed_run(Repo, fn -> delete_org!(fx) end)
	end
end

defp outcome({:ok, %AgentRelationship{revoked_at: %DateTime{}}}), do: :revoked
defp outcome({:error, :forbidden}), do: :forbidden

defp insert_org_with_admins!() do
	admin_role = Roles.id!(Repo, "org.admin")
	alice = Repo.insert!(Person.changeset(%{
		name: Factory.str("some name"), user: Factory.str("some user"),
		email: "#{Factory.str("user")}@example.com"}))
	bob = Repo.insert!(Person.changeset(%{
		name: Factory.str("some name"), user: Factory.str("some user"),
		email: "#{Factory.str("user")}@example.com"}))
	carol = Repo.insert!(Person.changeset(%{
		name: Factory.str("some name"), user: Factory.str("some user"),
		email: "#{Factory.str("user")}@example.com"}))
	org = Repo.insert!(Organization.changeset(%Organization{}, %{name: Factory.str("some name")}))
	alice_rel = Repo.insert!(%AgentRelationship{subject_id: alice.id, object_id: org.id,
		in_scope_of_id: org.id, relationship_id: admin_role})
	bob_rel = Repo.insert!(%AgentRelationship{subject_id: bob.id, object_id: org.id,
		in_scope_of_id: org.id, relationship_id: admin_role})
	carol_rel = Repo.insert!(%AgentRelationship{subject_id: carol.id, object_id: org.id,
		in_scope_of_id: org.id, relationship_id: admin_role})
	%{alice: alice, bob: bob, carol: carol, org: org,
		alice_rel: alice_rel, bob_rel: bob_rel, carol_rel: carol_rel}
end

defp delete_org!(fixtures) do
	Repo.delete_all(from r in AgentRelationship, where: r.object_id == ^fixtures.org.id)
	Repo.delete!(fixtures.alice)
	Repo.delete!(fixtures.bob)
	Repo.delete!(fixtures.carol)
	Repo.delete!(fixtures.org)
end
end
