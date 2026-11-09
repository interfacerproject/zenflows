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

defmodule ZenflowsTest.Authz.ConcurrencyInvites do
@moduledoc """
An event attaching to a process through the invited-party rule races an
`updateIntent(finished: true)` on the inviting intent.  `EventFacts`
locks the process's unfinished intents `FOR SHARE` (with
`finished = false` in the locking WHERE); the intent update locks the
intent row `FOR NO KEY UPDATE` first.  The two conflict, so they
serialize: either the event goes first and succeeds, or the finish goes
first and the event is denied -- never an exception.  Also: decisions
that read an intent's parties (satisfaction create) lock it `FOR SHARE`
and so see a concurrent party change.
Runs outside the SQL sandbox to get real concurrent transactions.
"""
use ExUnit.Case, async: false

import Ecto.Query, only: [from: 2]

alias Ecto.Adapters.SQL.Sandbox
alias Zenflows.Authz.{ExecutionContext, ObjectControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.{EconomicEvent, Intent, Person, Process, Satisfaction}
alias ZenflowsTest.Help.Factory

defp ctx(per), do: ExecutionContext.from_resolution(%{context: %{req_user: per}})

setup do
	on_exit(fn -> Sandbox.unboxed_run(Repo, fn -> Repo.query!("TRUNCATE zf_permission_log") end) end)
	:ok
end

test "finish goes first (held open): the waiting event is then denied" do
	fx = Sandbox.unboxed_run(Repo, fn -> fixtures!() end)
	task_fin = parked_task(fn -> finish(fx) end)

	try do
		assert_receive :locked, 2_000
		task_evt = unboxed_task(fn -> attach(fx) end)
		# Blocked on the intent row the finish holds, not dead.
		assert Task.yield(task_evt, 300) == nil

		send(task_fin.pid, :commit)
		assert {:ok, %Intent{finished: true}} = Task.await(task_fin, 2_000)
		assert {:error, :forbidden} = Task.await(task_evt, 2_000)
	after
		send(task_fin.pid, :commit)
		Sandbox.unboxed_run(Repo, fn -> cleanup!(fx) end)
	end
end

test "event goes first (held open): it succeeds, the waiting finish then succeeds" do
	fx = Sandbox.unboxed_run(Repo, fn -> fixtures!() end)
	task_evt = parked_task(fn -> attach(fx) end)

	try do
		assert_receive :locked, 2_000
		task_fin = unboxed_task(fn -> finish(fx) end)
		# Blocked on the FOR SHARE lock the event holds on the intent.
		assert Task.yield(task_fin, 300) == nil

		send(task_evt.pid, :commit)
		assert {:ok, %EconomicEvent{}} = Task.await(task_evt, 2_000)
		assert {:ok, %Intent{finished: true}} = Task.await(task_fin, 2_000)
	after
		send(task_evt.pid, :commit)
		Sandbox.unboxed_run(Repo, fn -> cleanup!(fx) end)
	end
end

test "free races never raise and always serialize one way or the other" do
	for _ <- 1..15 do
		fx = Sandbox.unboxed_run(Repo, fn -> fixtures!() end)

		try do
			task_evt = rescuing_task(fn -> attach(fx) end)
			task_fin = rescuing_task(fn -> finish(fx) end)
			re = Task.await(task_evt, 5_000)
			rf = Task.await(task_fin, 5_000)

			refute match?({:raised, _}, re), "event raised: #{inspect(re)}"
			refute match?({:raised, _}, rf), "finish raised: #{inspect(rf)}"
			assert {:ok, %Intent{finished: true}} = rf
			assert match?({:ok, %EconomicEvent{}}, re) or re == {:error, :forbidden},
				"unexpected event outcome: #{inspect(re)}"
		after
			Sandbox.unboxed_run(Repo, fn -> cleanup!(fx) end)
		end
	end
end

test "satisfaction create waits for a concurrent change of the intent's parties and sees it" do
	fx = Sandbox.unboxed_run(Repo, fn -> sat_fixtures!(fixtures!()) end)

	# The process controller moves the intent to another provider,
	# keeping the transaction (and its intent row lock) open.
	task_up = parked_task(fn ->
		Intent.Domain.update(ctx(fx.proposer), fx.sat_intent.id, %{provider_id: fx.stranger.id})
	end)

	try do
		assert_receive :locked, 2_000
		task_sat = unboxed_task(fn ->
			Satisfaction.Domain.create(ctx(fx.party),
				%{satisfies_id: fx.sat_intent.id, satisfied_by_event_id: fx.sat_event.id})
		end)
		# `Facts.for_satisfaction_create/3` locks the intent FOR SHARE.
		assert Task.yield(task_sat, 300) == nil

		send(task_up.pid, :commit)
		assert {:ok, %Intent{}} = Task.await(task_up, 2_000)
		# Judged against the committed parties: the event no longer shares one.
		assert {:error, :forbidden} = Task.await(task_sat, 2_000)
	after
		send(task_up.pid, :commit)
		Sandbox.unboxed_run(Repo, fn ->
			Repo.delete_all(from s in Satisfaction, where: s.satisfies_id == ^fx.sat_intent.id)
			Repo.delete_all(from e in EconomicEvent, where: e.id == ^fx.sat_event.id)
			Repo.delete_all(from c in ObjectControl, where: c.target_id == ^fx.sat_intent.id)
			Repo.delete_all(from i in Intent, where: i.id == ^fx.sat_intent.id)
			Repo.delete_all(from p in Person, where: p.id in ^[fx.party.id, fx.stranger.id])
			cleanup!(fx)
		end)
	end
end

# The invited owner attaches a `work` event to the proposer's process.
defp attach(fx) do
	EconomicEvent.Domain.create(ctx(fx.owner), %{
		action_id: "work", provider_id: fx.owner.id, receiver_id: fx.owner.id,
		input_of_id: fx.process.id, resource_conforms_to_id: fx.spec.id,
		effort_quantity: %{has_numerical_value: "1", has_unit_id: fx.unit.id},
		has_point_in_time: Factory.now(),
	})
end

# The proposer (controller of the intent) finishes the inviting intent.
defp finish(fx), do: Intent.Domain.update(ctx(fx.proposer), fx.intent.id, %{finished: true})

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

defp unboxed_task(fun), do: Task.async(fn -> Sandbox.unboxed_run(Repo, fun) end)

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
	proposer = insert_person!()
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	process = Factory.insert_process!(proposer)
	intent = Intent.Domain.create!(ctx(proposer), %{
		action_id: "work", input_of_id: process.id, receiver_id: owner.id})
	%{owner: owner, proposer: proposer, unit: unit, spec: spec, process: process, intent: intent}
end

defp sat_fixtures!(fx) do
	party = insert_person!()
	stranger = insert_person!()
	intent = Intent.Domain.create!(ctx(fx.proposer), %{action_id: "work",
		input_of_id: fx.process.id, provider_id: party.id})
	event = EconomicEvent.Domain.create!(ctx(party), %{action_id: "deliverService",
		provider_id: party.id, receiver_id: party.id, resource_conforms_to_id: fx.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: fx.unit.id},
		has_point_in_time: Factory.now()})
	Map.merge(fx, %{party: party, stranger: stranger, sat_intent: intent, sat_event: event})
end

defp cleanup!(fx) do
	Repo.delete_all(from e in EconomicEvent, where: e.input_of_id == ^fx.process.id)
	Repo.delete_all(from c in ObjectControl, where: c.target_id in ^[fx.process.id, fx.intent.id])
	Repo.delete_all(from i in Intent, where: i.id == ^fx.intent.id)
	Repo.delete_all(from p in Process, where: p.id == ^fx.process.id)
	Repo.delete_all(from p in Person, where: p.id in ^[fx.owner.id, fx.proposer.id])
	Repo.delete!(fx.spec)
	Repo.delete!(fx.unit)
end
end
