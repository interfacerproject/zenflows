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

defmodule ZenflowsTest.Authz.ConcurrencyObjects do
@moduledoc """
Concurrency around `zf_object_control` (processes and intents).
Runs outside the SQL sandbox to get real concurrent transactions.
async: false modules run alone, after all async modules.
"""
use ExUnit.Case, async: false

import Ecto.Query, only: [from: 2]

alias Ecto.Adapters.SQL.Sandbox
alias Zenflows.Authz.{ExecutionContext, ObjectControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.{
	EconomicEvent,
	Intent,
	Person,
	Process,
	Proposal,
}
alias ZenflowsTest.Help.Factory

defp ctx(per), do: ExecutionContext.from_resolution(%{context: %{req_user: per}})
defp admin_ctx(), do: ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})

setup do
	fx = Sandbox.unboxed_run(Repo, fn -> fixtures!() end)

	on_exit(fn ->
		Sandbox.unboxed_run(Repo, fn -> cleanup!(fx) end)
	end)

	fx
end

test "an event attaching to a process is denied once a concurrent assign moves control away", c do
	# Task A: an admin-key `assignObjectControl` moves `c.process`'s
	# control from `c.owner` to `c.other`, inside an explicit outer
	# transaction kept open (so the `FOR UPDATE` lock
	# `ObjectControl.Domain.assign/5` takes on the control row stays
	# held) until the test tells it to commit.
	task_a = parked_task(fn ->
		ObjectControl.Domain.assign(admin_ctx(), "process", c.process.id, c.other.id, "test reassign")
	end)

	try do
		assert_receive :locked, 2_000

		# Task B: the original owner tries to attach a "work" event to the
		# same process. `EventFacts.load/3` locks the process's control
		# row `FOR SHARE`, so it must simply wait on the row A holds
		# `FOR UPDATE`.
		task_b = unboxed_task(fn -> attach_event(c) end)

		# B must be blocked waiting on a lock A holds, not dead: a real
		# deadlock would make Postgres kill one side with a 40P01 error
		# (raised as an exception) well before this timeout, crashing the
		# task instead of leaving it merely pending.
		assert Task.yield(task_b, 300) == nil

		send(task_a.pid, :commit)

		assert {:ok, %ObjectControl{controller_id: other_id}} = Task.await(task_a, 2_000)
		assert other_id == c.other.id
		# By the time B's event actually runs, A has already committed the
		# reassignment, so the original owner no longer controls the
		# process and is denied -- not an exception, not a deadlock.
		assert {:error, :forbidden} = Task.await(task_b, 2_000)
	after
		# If an assertion above failed, task A would otherwise stay parked
		# in its `receive`, holding its row lock forever and hanging the
		# setup's `on_exit` cleanup. Always unblock it; this send is
		# harmless if `:commit` was already delivered above.
		send(task_a.pid, :commit)
	end
end

test "updateIntent(finished: true) by a party and deleteIntent by the controller never raise", _c do
	# `Facts.for_intent_update/3` and `Facts.for_object/4` (used by
	# `intent.delete`) lock the same two rows -- the intent itself
	# (`FOR NO KEY UPDATE`) then its `zf_object_control` row
	# (`FOR UPDATE`) -- in the same order, so the two operations always
	# serialize one way or the other; neither can deadlock the other.
	# Repeated, since any single pair of tasks may or may not happen to
	# race.
	for _ <- 1..15 do
		fx = Sandbox.unboxed_run(Repo, fn -> intent_fixtures!() end)

		try do
			task_up = rescuing_task(fn ->
				Intent.Domain.update(ctx(fx.party), fx.intent.id, %{finished: true})
			end)
			task_del = rescuing_task(fn ->
				Intent.Domain.delete(ctx(fx.controller), fx.intent.id)
			end)

			ru = Task.await(task_up, 5_000)
			rd = Task.await(task_del, 5_000)

			refute match?({:raised, _}, ru), "update raised: #{inspect(ru)}"
			refute match?({:raised, _}, rd), "delete raised: #{inspect(rd)}"

			# The controller's right to delete the intent never depends on
			# whether the party's `finished: true` update landed first or
			# not, so the delete always succeeds.
			assert match?({:ok, _}, rd), "delete unexpectedly denied: #{inspect(rd)}"
			# The update either lands before the delete (ok), or finds the
			# intent already gone by the time it gets its locks and is
			# denied -- never anything else.
			assert match?({:ok, _}, ru) or ru == {:error, :forbidden},
				"unexpected update outcome: #{inspect(ru)}"
		after
			Sandbox.unboxed_run(Repo, fn -> intent_cleanup!(fx) end)
		end
	end

	Sandbox.unboxed_run(Repo, fn -> Repo.query!("TRUNCATE zf_permission_log") end)
end

test "concurrent first-time assigns on a legacy object serialize: no primary-key exception", c do
	# Parked: the first assign holds the target row (FOR NO KEY UPDATE)
	# and its freshly inserted control row; the second waits on the
	# target row, then finds and replaces that control row.
	prop = Sandbox.unboxed_run(Repo, fn -> Repo.insert!(%Proposal{name: Factory.str("legacy")}) end)
	task_a = parked_task(fn ->
		ObjectControl.Domain.assign(admin_ctx(), "proposal", prop.id, c.owner.id, "first")
	end)

	try do
		assert_receive :locked, 2_000
		task_b = unboxed_task(fn ->
			ObjectControl.Domain.assign(admin_ctx(), "proposal", prop.id, c.other.id, "second")
		end)
		assert Task.yield(task_b, 300) == nil

		send(task_a.pid, :commit)
		assert {:ok, %ObjectControl{epoch: 0}} = Task.await(task_a, 2_000)
		assert {:ok, %ObjectControl{epoch: 1, controller_id: cid}} = Task.await(task_b, 2_000)
		assert cid == c.other.id
	after
		send(task_a.pid, :commit)
		Sandbox.unboxed_run(Repo, fn -> proposal_cleanup!(prop) end)
	end

	# Free races, repeated.
	for _ <- 1..10 do
		prop = Sandbox.unboxed_run(Repo, fn -> Repo.insert!(%Proposal{name: Factory.str("legacy")}) end)

		try do
			tasks = for per <- [c.owner, c.other] do
				rescuing_task(fn ->
					ObjectControl.Domain.assign(admin_ctx(), "proposal", prop.id, per.id, "race")
				end)
			end
			results = Enum.map(tasks, &Task.await(&1, 5_000))
			assert Enum.all?(results, &match?({:ok, %ObjectControl{}}, &1)), inspect(results)
			assert results |> Enum.map(fn {:ok, oc} -> oc.epoch end) |> Enum.sort() == [0, 1]
		after
			Sandbox.unboxed_run(Repo, fn -> proposal_cleanup!(prop) end)
		end
	end
end

defp proposal_cleanup!(prop) do
	Repo.delete_all(from c in ObjectControl, where: c.target_type == "proposal" and c.target_id == ^prop.id)
	Repo.delete_all(from p in Proposal, where: p.id == ^prop.id)
end

defp attach_event(c) do
	EconomicEvent.Domain.create(ctx(c.owner), %{
		action_id: "work", provider_id: c.owner.id, receiver_id: c.owner.id,
		input_of_id: c.process.id, resource_conforms_to_id: c.spec.id,
		effort_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	})
end

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

defp insert_person!() do
	Repo.insert!(Person.changeset(%{
		name: Factory.str("some name"), user: Factory.str("some user"),
		email: "#{Factory.str("user")}@example.com"}))
end

defp fixtures!() do
	owner = insert_person!()
	other = insert_person!()
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	process = Factory.insert_process!(owner)
	%{owner: owner, other: other, unit: unit, spec: spec, process: process}
end

defp cleanup!(fx) do
	Repo.delete_all(from c in ObjectControl, where: c.target_type == "process" and c.target_id == ^fx.process.id)
	Repo.delete_all(from p in Process, where: p.id == ^fx.process.id)
	Repo.delete_all(from p in Person, where: p.id in [^fx.owner.id, ^fx.other.id])
	Repo.delete!(fx.spec)
	Repo.delete!(fx.unit)
	Repo.query!("TRUNCATE zf_permission_log")
end

defp intent_fixtures!() do
	controller = insert_person!()
	party = insert_person!()
	process = Factory.insert_process!(controller)
	intent = Intent.Domain.create!(ctx(controller), %{
		action_id: "cite", input_of_id: process.id, provider_id: party.id})
	%{controller: controller, party: party, process: process, intent: intent}
end

defp intent_cleanup!(fx) do
	# Whichever side ran last, the intent (and its own control row) is
	# always gone by now -- these are defensive no-ops in that case.
	Repo.delete_all(from c in ObjectControl, where: c.target_type == "intent" and c.target_id == ^fx.intent.id)
	Repo.delete_all(from i in Intent, where: i.id == ^fx.intent.id)
	Repo.delete_all(from c in ObjectControl, where: c.target_type == "process" and c.target_id == ^fx.process.id)
	Repo.delete_all(from p in Process, where: p.id == ^fx.process.id)
	Repo.delete_all(from p in Person, where: p.id in [^fx.controller.id, ^fx.party.id])
end
end
