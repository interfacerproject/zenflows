# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule ZenflowsTest.Authz.AcceptContributionConcurrency do
@moduledoc """
`acceptContribution` against concurrent accepts, rejects and metadata
patches, on real separate PostgreSQL connections (outside the sandbox).
"""
use ExUnit.Case, async: false

import Ecto.Query, only: [from: 2]

alias Ecto.Adapters.SQL.Sandbox
alias Zenflows.Authz.{ObjectControl, ResourceControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.{EconomicEvent, EconomicResource, Intent, Person, Process, Proposal, ProposedIntent, Satisfaction}
alias Zenflows.VF.Proposal.Contribution
alias ZenflowsTest.Help.Factory

setup do
	fx = Sandbox.unboxed_run(Repo, &fixtures!/0)
	on_exit(fn -> Sandbox.unboxed_run(Repo, fn ->
		cleanup!(fx)
		Repo.query!("TRUNCATE zf_permission_log")
	end) end)
	fx
end

defp insert_person!() do
	Repo.insert!(Person.changeset(%{
		name: Factory.str("some name"), user: Factory.str("some user"),
		email: "#{Factory.str("user")}@example.com"}))
end

defp raise!(owner, unit, spec, metadata) do
	EconomicEvent.Domain.create!(Factory.ctx(owner), %{
		action_id: "raise", provider_id: owner.id, receiver_id: owner.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
		has_point_in_time: Factory.now(), resource_metadata: metadata,
	}, %{name: Factory.str("res")})
end

defp fixtures!() do
	alice = insert_person!()
	bob = insert_person!()
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	origin_evt = raise!(alice, unit, spec, %{"keep" => "me", "relations" => []})
	fork_evt = raise!(bob, unit, spec, nil)
	origin = origin_evt.resource_inventoried_as_id
	fork = fork_evt.resource_inventoried_as_id
	process = Factory.insert_process!(bob).id
	qty = %{has_numerical_value: "1", has_unit_id: unit.id}
	intent = fn params -> Intent.Domain.create!(Factory.ctx(bob), Map.merge(%{resource_quantity: qty}, params)).id end
	cite = intent.(%{action_id: "cite", input_of_id: process, provider_id: bob.id, resource_inventoried_as_id: fork})
	accept = intent.(%{action_id: "accept", input_of_id: process, receiver_id: alice.id, resource_inventoried_as_id: origin})
	modify = intent.(%{action_id: "modify", output_of_id: process, receiver_id: alice.id, resource_inventoried_as_id: origin})
	proposal = Proposal.Domain.create!(Factory.ctx(bob), %{name: "Contribution to resource"}).id
	for i <- [cite, accept, modify],
		do: ProposedIntent.Domain.create!(Factory.ctx(bob), %{published_in_id: proposal, publishes_id: i})
	%{alice: alice, bob: bob, unit: unit, spec: spec, origin: origin, fork: fork, process: process,
		cite: cite, accept: accept, modify: modify, proposal: proposal,
		raise_events: [origin_evt.id, fork_evt.id]}
end

defp cleanup!(fx) do
	intents = [fx.cite, fx.accept, fx.modify]
	resources = [fx.origin, fx.fork]
	[origin_evt, fork_evt] = fx.raise_events
	Repo.update_all(from(r in EconomicResource, where: r.id == ^fx.origin), set: [previous_event_id: origin_evt])
	Repo.update_all(from(r in EconomicResource, where: r.id == ^fx.fork), set: [previous_event_id: fork_evt])
	Repo.delete_all(from s in Satisfaction, where: s.satisfies_id in ^intents)
	Repo.delete_all(from e in EconomicEvent, where: e.input_of_id == ^fx.process or e.output_of_id == ^fx.process)
	Repo.update_all(from(e in EconomicEvent, where: e.id in ^fx.raise_events), set: [resource_inventoried_as_id: nil])
	Repo.delete_all(from p in ProposedIntent, where: p.published_in_id == ^fx.proposal)
	Repo.delete_all(from c in ObjectControl, where: c.target_id in ^[fx.process, fx.proposal | intents])
	Repo.delete_all(from i in Intent, where: i.id in ^intents)
	Repo.delete_all(from p in Proposal, where: p.id == ^fx.proposal)
	Repo.delete_all(from p in Process, where: p.id == ^fx.process)
	Repo.delete_all(from c in ResourceControl, where: c.resource_id in ^resources)
	Repo.delete_all(from r in EconomicResource, where: r.id in ^resources)
	Repo.delete_all(from e in EconomicEvent, where: e.id in ^fx.raise_events)
	Repo.delete_all(from p in Person, where: p.id in ^[fx.alice.id, fx.bob.id])
	Repo.delete!(fx.spec)
	Repo.delete!(fx.unit)
end

defp task(fun), do: Task.async(fn -> Sandbox.unboxed_run(Repo, fun) end)
defp parked(fun) do
	parent = self()
	task(fn ->
		{:ok, result} = Repo.transaction(fn ->
			result = fun.()
			send(parent, :locked)
			receive do :commit -> :ok after 10_000 -> Repo.rollback(:park_timeout) end
			result
		end)
		result
	end)
end

defp accept(fx), do: Contribution.accept(Factory.ctx(fx.alice), fx.proposal)
defp reject(fx) do
	for id <- [fx.cite, fx.accept, fx.modify],
		do: {:ok, _} = Intent.Domain.update(Factory.ctx(fx.alice), id, %{finished: true})
	:rejected
end
defp ids(r), do: Enum.map([r.cite_event, r.accept_event, r.modify_event], & &1.id)
defp db(fun), do: Sandbox.unboxed_run(Repo, fun)
defp event_count(fx),
	do: db(fn -> Repo.aggregate(from(e in EconomicEvent, where: e.input_of_id == ^fx.process or e.output_of_id == ^fx.process), :count) end)

test "a second accept waits for the first and returns the same events", fx do
	a = parked(fn -> accept(fx) end)
	try do
		assert_receive :locked, 2_000
		b = task(fn -> accept(fx) end)
		assert Task.yield(b, 300) == nil
		send(a.pid, :commit)
		assert {:ok, ra} = Task.await(a)
		assert {:ok, rb} = Task.await(b)
		assert ids(ra) == ids(rb)
		assert event_count(fx) == 3
	after
		send(a.pid, :commit)
	end
end

test "free concurrent accepts never raise and write one set of events", fx do
	results =
		for(_ <- 1..4, do: task(fn -> try do accept(fx) rescue e -> {:raised, e} end end))
		|> Enum.map(&Task.await(&1, 10_000))
	assert [{:ok, first} | _] = results
	assert Enum.all?(results, &match?({:ok, r} when is_map(r), &1))
	assert results |> Enum.map(fn {:ok, r} -> ids(r) end) |> Enum.uniq() == [ids(first)]
	assert event_count(fx) == 3
end

test "a reject holding the intents first makes the waiting accept a CONFLICT", fx do
	r = parked(fn -> reject(fx) end)
	try do
		assert_receive :locked, 2_000
		a = task(fn -> accept(fx) end)
		assert Task.yield(a, 300) == nil
		send(r.pid, :commit)
		assert :rejected = Task.await(r)
		assert {:error, :proposal_not_pending} = Task.await(a)
		assert event_count(fx) == 0
		assert db(fn -> Proposal.Domain.status(fx.proposal) end) == {:ok, :refused}
	after
		send(r.pid, :commit)
	end
end

test "an accept holding the intents first: the waiting reject runs after, status stays ACCEPTED", fx do
	a = parked(fn -> accept(fx) end)
	try do
		assert_receive :locked, 2_000
		r = task(fn -> reject(fx) end)
		assert Task.yield(r, 300) == nil
		send(a.pid, :commit)
		assert {:ok, _} = Task.await(a)
		assert :rejected = Task.await(r)
		assert db(fn -> Proposal.Domain.status(fx.proposal) end) == {:ok, :accepted}
	after
		send(a.pid, :commit)
	end
end

test "a concurrent metadata patch on the origin is kept alongside the new relation", fx do
	p = parked(fn -> EconomicResource.Domain.patch_metadata(Factory.ctx(fx.alice), fx.origin, %{"patched" => true}) end)
	try do
		assert_receive :locked, 2_000
		a = task(fn -> accept(fx) end)
		assert Task.yield(a, 300) == nil
		send(p.pid, :commit)
		assert {:ok, _} = Task.await(p)
		assert {:ok, _} = Task.await(a)
		assert db(fn -> EconomicResource.Domain.one!(fx.origin).metadata end) ==
			%{"keep" => "me", "patched" => true, "relations" => [fx.fork]}
	after
		send(p.pid, :commit)
	end
end
end
