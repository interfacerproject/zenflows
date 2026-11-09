# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule ZenflowsTest.Authz.ProposeContributionConcurrency do
@moduledoc "Concurrent `proposeContribution` calls on real separate PostgreSQL connections."
use ExUnit.Case, async: false

import Ecto.Query, only: [from: 2]

alias Ecto.Adapters.SQL.Sandbox
alias Zenflows.Authz.{ObjectControl, ResourceControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.{EconomicEvent, EconomicResource, Intent, Person, Process, Proposal, ProposedIntent}
alias Zenflows.VF.Proposal.Propose
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

defp raise!(owner, unit, spec) do
	EconomicEvent.Domain.create!(Factory.ctx(owner), %{
		action_id: "raise", provider_id: owner.id, receiver_id: owner.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: Factory.str("res")})
end

defp fixtures!() do
	alice = insert_person!()
	bob = insert_person!()
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	o = raise!(alice, unit, spec)
	f = raise!(bob, unit, spec)
	%{alice: alice, bob: bob, unit: unit, spec: spec,
		origin: o.resource_inventoried_as_id, fork: f.resource_inventoried_as_id, raise_events: [o.id, f.id]}
end

defp cleanup!(fx) do
	intents = Repo.all(from i in Intent, where: i.resource_inventoried_as_id in ^[fx.origin, fx.fork], select: i.id)
	processes = Repo.all(from i in Intent, where: i.id in ^intents and not is_nil(i.input_of_id), select: i.input_of_id, distinct: true)
	proposals = Repo.all(from p in ProposedIntent, where: p.publishes_id in ^intents, select: p.published_in_id, distinct: true)
	Repo.delete_all(from p in ProposedIntent, where: p.publishes_id in ^intents)
	Repo.delete_all(from c in ObjectControl, where: c.target_id in ^(intents ++ processes ++ proposals))
	Repo.delete_all(from i in Intent, where: i.id in ^intents)
	Repo.delete_all(from p in Proposal, where: p.id in ^proposals)
	Repo.delete_all(from p in Process, where: p.id in ^processes)
	Repo.update_all(from(e in EconomicEvent, where: e.id in ^fx.raise_events), set: [resource_inventoried_as_id: nil])
	Repo.delete_all(from c in ResourceControl, where: c.resource_id in ^[fx.origin, fx.fork])
	Repo.delete_all(from r in EconomicResource, where: r.id in ^[fx.origin, fx.fork])
	Repo.delete_all(from e in EconomicEvent, where: e.id in ^fx.raise_events)
	Repo.delete_all(from p in Person, where: p.id in ^[fx.alice.id, fx.bob.id])
	Repo.delete!(fx.spec)
	Repo.delete!(fx.unit)
end

defp task(fun), do: Task.async(fn -> Sandbox.unboxed_run(Repo, fun) end)

test "concurrent identical proposals create one proposal; every caller gets it", fx do
	params = %{resource_forked_id: fx.fork, resource_origin_id: fx.origin}
	results =
		for(_ <- 1..4, do: task(fn ->
			try do Propose.propose(Factory.ctx(fx.bob), params) rescue e -> {:raised, e} end
		end))
		|> Enum.map(&Task.await(&1, 10_000))
	assert Enum.all?(results, &match?({:ok, %{proposal: _}}, &1)), inspect(results)
	assert results |> Enum.map(fn {:ok, r} -> r.proposal.id end) |> Enum.uniq() |> length() == 1
	assert Enum.count(results, fn {:ok, r} -> r.created end) == 1
	assert Sandbox.unboxed_run(Repo, fn ->
		Repo.aggregate(from(i in Intent, where: i.resource_inventoried_as_id == ^fx.fork), :count)
	end) == 1
end
end
