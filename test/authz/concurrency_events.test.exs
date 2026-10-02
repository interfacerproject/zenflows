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

defmodule ZenflowsTest.Authz.ConcurrencyEvents do
# Runs outside the SQL sandbox to get real concurrent transactions.
# async: false modules run alone, after all async modules.
use ExUnit.Case, async: false

import Ecto.Query, only: [from: 2]

alias Ecto.Adapters.SQL.Sandbox
alias Zenflows.Authz.{ExecutionContext, Roles}
alias Zenflows.DB.Repo
alias Zenflows.VF.{
	AgentRelationship,
	EconomicEvent,
	EconomicResource,
	Organization,
	Person,
	ResourceSpecification,
	Unit,
}
alias ZenflowsTest.Help.Factory

defp ctx(per), do: ExecutionContext.from_resolution(%{context: %{req_user: per}})

setup do
	fx = Sandbox.unboxed_run(Repo, fn -> fixtures!() end)

	on_exit(fn ->
		Sandbox.unboxed_run(Repo, fn -> cleanup!(fx) end)
	end)

	fx
end

test "opposite transfers between the same two resources do not deadlock", c do
	# `EventFacts.load/3` locks every touched resource (here, both r1 and
	# r2) in one query ordered by id, so a transfer of r1 -> r2 and a
	# concurrent transfer of r2 -> r1 always acquire the two row locks in
	# the same order, whichever task gets there first. A genuine circular
	# wait (and the 40P01 "deadlock detected" error Postgres would raise
	# for it) is impossible; at worst one task blocks until the other
	# commits. Repeated, since any single pair of tasks may or may not
	# happen to race.
	for _ <- 1..15 do
		task_a = rescuing_task(fn -> transfer(c, c.r1, c.r2) end)
		task_b = rescuing_task(fn -> transfer(c, c.r2, c.r1) end)

		ra = Task.await(task_a, 5_000)
		rb = Task.await(task_b, 5_000)

		for r <- [ra, rb] do
			refute match?({:raised, %Postgrex.Error{postgres: %{code: :deadlock_detected}}}, r),
				"deadlocked: #{inspect(r)}"
			assert match?({:ok, _}, r) or match?({:error, b} when is_binary(b), r),
				"unexpected outcome: #{inspect(r)}"
		end
	end
end

test "event waiting on a revoke of the signer's admin role is denied", c do
	parent = self()

	# Task A: bob revokes alice's org.admin relationship, inside an
	# explicit outer transaction kept open (so the row lock
	# `AgentRelationship.Domain.delete/2` takes on alice's relationship
	# row stays held) until the test tells it to commit.
	task_a = Task.async(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			Repo.transaction(fn ->
				{:ok, _} = AgentRelationship.Domain.delete(ctx(c.bob), c.alice_rel.id)
				send(parent, :locked)
				receive do
					:commit -> :ok
				end
			end)
		end)
	end)

	try do
		assert_receive :locked, 2_000

		# Task B: alice (while A is still mid-transaction, holding the
		# lock on her own admin row) tries to lower r1. `EventFacts.load/3`
		# locks the admin rows the decision needs FOR SHARE, so it must
		# simply wait on the row A holds FOR UPDATE.
		task_b = Task.async(fn ->
			Sandbox.unboxed_run(Repo, fn -> lower(c, c.r1) end)
		end)

		# B must be blocked waiting on a lock A holds, not dead: a real
		# deadlock would make Postgres kill one side with a 40P01 error
		# (raised as an exception) well before this timeout, crashing the
		# task instead of leaving it merely pending.
		assert Task.yield(task_b, 300) == nil

		send(task_a.pid, :commit)

		assert {:ok, _} = Task.await(task_a, 2_000)
		# By the time B's lower actually runs, A has already committed
		# alice's own revocation, so alice is no longer an active admin
		# and is denied -- not an exception, not a deadlock.
		assert {:error, :forbidden} = Task.await(task_b, 2_000)
	after
		# If an assertion above failed, task A would otherwise stay parked
		# in its `receive`, holding its row lock forever and hanging the
		# setup's `on_exit` cleanup. Always unblock it; this send is
		# harmless if `:commit` was already delivered above.
		send(task_a.pid, :commit)
	end
end

defp transfer(c, from_id, to_id) do
	EconomicEvent.Domain.create(ctx(c.alice), %{
		action_id: "transfer", provider_id: c.org.id, receiver_id: c.org.id,
		resource_inventoried_as_id: from_id, to_resource_inventoried_as_id: to_id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	})
end

defp lower(c, res_id) do
	EconomicEvent.Domain.create(ctx(c.alice), %{
		action_id: "lower", provider_id: c.org.id, receiver_id: c.org.id,
		resource_inventoried_as_id: res_id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	})
end

defp rescuing_task(fun) do
	Task.async(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			try do
				fun.()
			rescue
				e -> {:raised, e}
			end
		end)
	end)
end

defp raise!(signer, org, unit, spec) do
	%{resource_inventoried_as_id: id} = EconomicEvent.Domain.create!(ctx(signer), %{
		action_id: "raise", provider_id: org.id, receiver_id: org.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "10", has_unit_id: unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: Factory.str("some name")})
	id
end

defp fixtures!() do
	alice = Repo.insert!(Person.changeset(%{
		name: Factory.str("alice"), user: Factory.str("alice"),
		email: "#{Factory.str("alice")}@example.com"}))
	bob = Repo.insert!(Person.changeset(%{
		name: Factory.str("bob"), user: Factory.str("bob"),
		email: "#{Factory.str("bob")}@example.com"}))
	org = Repo.insert!(Organization.changeset(%{name: Factory.str("some org")}))
	unit = Repo.insert!(Unit.changeset(%{
		label: Factory.str("some label"), symbol: Factory.str("some symbol")}))
	spec = Repo.insert!(ResourceSpecification.changeset(%{name: Factory.str("some spec")}))

	alice_rel = Repo.insert!(%AgentRelationship{subject_id: alice.id, object_id: org.id,
		in_scope_of_id: org.id, relationship_id: Roles.id!(Repo, "org.admin")})
	bob_rel = Repo.insert!(%AgentRelationship{subject_id: bob.id, object_id: org.id,
		in_scope_of_id: org.id, relationship_id: Roles.id!(Repo, "org.admin")})

	%{alice: alice, bob: bob, org: org, unit: unit, spec: spec,
		alice_rel: alice_rel, bob_rel: bob_rel,
		r1: raise!(alice, org, unit, spec), r2: raise!(alice, org, unit, spec)}
end

defp cleanup!(fx) do
	# `vf_economic_resource.previous_event_id` is NOT NULL, so it can't be
	# cleared the way `contained_in_id` is; instead, the event <-> resource
	# cycle is broken from the event side (both `resource_inventoried_as_id`
	# and `to_resource_inventoried_as_id` are nullable there) before either
	# table's rows are deleted. Event ids are captured up front, since
	# they're no longer findable by resource id once that link is cleared.
	res_ids = Repo.all(from r in EconomicResource,
		where: r.primary_accountable_id == ^fx.org.id or r.primary_accountable_id == ^fx.alice.id,
		select: r.id)
	evt_ids = Repo.all(from e in EconomicEvent,
		where: e.resource_inventoried_as_id in ^res_ids or e.to_resource_inventoried_as_id in ^res_ids,
		select: e.id)

	Repo.update_all(from(r in EconomicResource, where: r.id in ^res_ids),
		set: [contained_in_id: nil])
	Repo.update_all(from(e in EconomicEvent, where: e.id in ^evt_ids),
		set: [resource_inventoried_as_id: nil, to_resource_inventoried_as_id: nil, previous_event_id: nil])
	Repo.delete_all(from r in EconomicResource, where: r.id in ^res_ids)
	Repo.delete_all(from e in EconomicEvent, where: e.id in ^evt_ids)
	Repo.delete_all(from r in AgentRelationship, where: r.object_id == ^fx.org.id)
	for x <- [fx.alice, fx.bob, fx.org, fx.unit, fx.spec], do: Repo.delete!(x)
	Repo.query!("TRUNCATE zf_permission_log")
end
end
