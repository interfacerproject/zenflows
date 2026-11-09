# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule ZenflowsTest.Authz.ProposeContribution do
@moduledoc """
`proposeContribution`: the proposer's process, three intents, the proposal
and its links in one transaction; owner = the origin's controller.
"""
use ZenflowsTest.Help.AbsinCase, async: false

import Ecto.Query
alias Zenflows.Authz.{ObjectControl, ResourceControl}
alias Zenflows.DB.{ID, Repo}
alias Zenflows.VF.{EconomicEvent, EconomicResource, Intent, Process, Proposal, ProposedIntent}
alias Zenflows.VF.Proposal.{Contribution, Propose}

@forbidden %{message: "forbidden", extensions: %{code: "FORBIDDEN"}}

setup do
	%{
		alice: Factory.insert!(:person),
		bob: Factory.insert!(:person),
		carol: Factory.insert!(:person),
		unit: Factory.insert!(:unit),
		spec: Factory.insert!(:resource_specification),
	}
end

defp raise!(c, owner) do
	EconomicEvent.Domain.create!(Factory.ctx(owner), %{
		action_id: "raise", provider_id: owner.id, receiver_id: owner.id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(), resource_metadata: %{"relations" => []},
	}, %{name: Factory.str("res")}).resource_inventoried_as_id
end

defp set_control!(res, agent),
	do: Repo.update_all(from(r in ResourceControl, where: r.resource_id == ^res), set: [controller_id: agent.id])

@propose """
	mutation Propose($fork: ID!, $origin: ID!, $note: String) {
		proposeContribution(resourceForkedId: $fork, resourceOriginId: $origin, note: $note) {
			created
			proposal { id status note }
			process { id }
			citeIntent { id action { id } provider { id } inputOf { id } resourceInventoriedAs { id } }
			acceptIntent { id action { id } receiver { id } inputOf { id } resourceInventoriedAs { id } }
			modifyIntent { id action { id } receiver { id } outputOf { id } resourceInventoriedAs { id } }
		}
	}
"""

defp counts(),
	do: Enum.map([Process, Intent, Proposal, ProposedIntent], &Repo.aggregate(&1, :count))

test "Bob proposes in one call; the owner is the origin's controller, not its primaryAccountable", c do
	# Alice created (custody, control) the origin; Carol is only primaryAccountable.
	origin = raise!(c, c.alice)
	Repo.update_all(from(r in EconomicResource, where: r.id == ^origin), set: [primary_accountable_id: c.carol.id])
	fork = raise!(c, c.bob)

	assert %{data: %{"proposeContribution" => out}} =
		run_as!(c.bob, @propose, vars: %{"fork" => fork, "origin" => origin, "note" => "my work"})
	assert out["created"] == true
	assert out["proposal"]["status"] == "PENDING"
	assert out["proposal"]["note"] == "my work"
	process = out["process"]["id"]
	assert out["citeIntent"]["provider"]["id"] == c.bob.id
	assert out["citeIntent"]["inputOf"]["id"] == process
	assert out["citeIntent"]["resourceInventoriedAs"]["id"] == fork
	assert out["acceptIntent"]["receiver"]["id"] == c.alice.id
	assert out["acceptIntent"]["inputOf"]["id"] == process
	assert out["modifyIntent"]["receiver"]["id"] == c.alice.id
	assert out["modifyIntent"]["outputOf"]["id"] == process
	assert out["acceptIntent"]["resourceInventoriedAs"]["id"] == origin

	assert Repo.get_by!(ObjectControl, target_type: "process", target_id: process).controller_id == c.bob.id
	assert Repo.get_by!(ObjectControl, target_type: "proposal", target_id: out["proposal"]["id"]).controller_id == c.bob.id

	# The controller can accept it end to end.
	assert {:ok, accepted} = Contribution.accept(Factory.ctx(c.alice), out["proposal"]["id"])
	assert accepted.proposal.id == out["proposal"]["id"]
	assert EconomicResource.Domain.one!(origin).metadata["relations"] == [fork]
end

test "a retry returns the pending proposal and writes nothing", c do
	origin = raise!(c, c.alice)
	fork = raise!(c, c.bob)
	assert {:ok, first} = Propose.propose(Factory.ctx(c.bob), %{resource_forked_id: fork, resource_origin_id: origin})
	assert first.created
	before = counts()
	assert {:ok, again} = Propose.propose(Factory.ctx(c.bob), %{resource_forked_id: fork, resource_origin_id: origin, note: "x"})
	refute again.created
	assert again.proposal.id == first.proposal.id
	assert again.cite_intent.id == first.cite_intent.id
	assert counts() == before
end

test "after a rejection a new proposal can be made", c do
	origin = raise!(c, c.alice)
	fork = raise!(c, c.bob)
	{:ok, first} = Propose.propose(Factory.ctx(c.bob), %{resource_forked_id: fork, resource_origin_id: origin})
	for i <- [first.cite_intent, first.accept_intent, first.modify_intent],
		do: {:ok, _} = Intent.Domain.update(Factory.ctx(c.alice), i.id, %{finished: true})
	assert {:ok, second} = Propose.propose(Factory.ctx(c.bob), %{resource_forked_id: fork, resource_origin_id: origin})
	assert second.created
	refute second.proposal.id == first.proposal.id
end

test "proposing someone else's resource as your fork is FORBIDDEN; nothing written", c do
	origin = raise!(c, c.alice)
	carols = raise!(c, c.carol)
	before = counts()
	assert %{errors: [err]} = run_as!(c.bob, @propose, vars: %{"fork" => carols, "origin" => origin})
	assert Map.take(err, [:message, :extensions]) == @forbidden
	assert counts() == before
end

test "fork = origin, an unknown resource and an origin without controller are BAD_USER_INPUT", c do
	origin = raise!(c, c.alice)
	fork = raise!(c, c.bob)
	before = counts()
	assert %{errors: [err]} = run_as!(c.alice, @propose, vars: %{"fork" => origin, "origin" => origin})
	assert err.extensions == %{code: "BAD_USER_INPUT"}
	assert {:error, {:bad_user_input, _}} =
		Propose.propose(Factory.ctx(c.bob), %{resource_forked_id: fork, resource_origin_id: ID.gen()})
	Repo.delete_all(from r in ResourceControl, where: r.resource_id == ^origin)
	assert {:error, {:bad_user_input, msg}} =
		Propose.propose(Factory.ctx(c.bob), %{resource_forked_id: fork, resource_origin_id: origin})
	assert msg =~ "controller"
	assert counts() == before
end

test "an organization-controlled origin makes the organization the owner; its admin can accept", c do
	org = Factory.insert!(:organization)
	Factory.insert_admin!(c.alice, org)
	origin = raise!(c, c.alice)
	set_control!(origin, org)
	Repo.update_all(from(r in EconomicResource, where: r.id == ^origin), set: [custodian_id: org.id])
	fork = raise!(c, c.bob)

	assert {:ok, p} = Propose.propose(Factory.ctx(c.bob), %{resource_forked_id: fork, resource_origin_id: origin})
	assert p.accept_intent.receiver_id == org.id
	assert p.modify_intent.receiver_id == org.id
	assert {:error, :forbidden} = Contribution.accept(Factory.ctx(c.carol), p.proposal.id)
	assert {:ok, _} = Contribution.accept(Factory.ctx(c.alice), p.proposal.id)
end

test "intent quantities follow each resource's on-hand quantity and unit", c do
	origin = raise!(c, c.alice)
	fork = raise!(c, c.bob)
	{:ok, p} = Propose.propose(Factory.ctx(c.bob), %{resource_forked_id: fork, resource_origin_id: origin})
	for i <- [p.cite_intent, p.accept_intent, p.modify_intent] do
		assert i.resource_quantity_has_unit_id == c.unit.id
		assert Decimal.equal?(i.resource_quantity_has_numerical_value, 1)
	end
end

test "a failure after the process was created rolls everything back", c do
	origin = raise!(c, c.alice)
	fork = raise!(c, c.bob)
	# The proposal is created after the process and the intents; a note over
	# the length limit makes it fail there.
	before = counts()
	assert {:error, %Ecto.Changeset{}} = Propose.propose(Factory.ctx(c.bob),
		%{resource_forked_id: fork, resource_origin_id: origin, note: String.duplicate("x", 100_000)})
	assert counts() == before
end
end
