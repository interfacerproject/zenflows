# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule ZenflowsTest.Authz.AcceptContribution do
@moduledoc """
`acceptContribution`: the owner's cite/accept/modify events and the three
satisfactions of a contribution proposal, in one transaction. Proposals are
built with the SDK's `proposeContribution` documents (see
`proposals_api.test.exs`).
"""
use ZenflowsTest.Help.AbsinCase, async: false

import Ecto.Query
alias Zenflows.DB.{ID, Repo}
alias Zenflows.VF.{EconomicEvent, EconomicResource, Intent, Proposal, Satisfaction}
alias Zenflows.VF.Proposal.Contribution

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

defp raise!(c, owner, metadata \\ nil) do
	EconomicEvent.Domain.create!(Factory.ctx(owner), %{
		action_id: "raise", provider_id: owner.id, receiver_id: owner.id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(), resource_metadata: metadata,
	}, %{name: Factory.str("res")}).resource_inventoried_as_id
end

@propose_contribution """
	mutation proposeContribution(
		$process: ID! $owner: ID! $proposer: ID! $creationTime: DateTime!
		$resourceForked: ID! $unitOne: ID! $resourceOrigin: ID!
	) {
		citeResourceForked: createIntent(intent: {
			action: "cite" inputOf: $process provider: $proposer hasPointInTime: $creationTime
			resourceInventoriedAs: $resourceForked resourceQuantity: { hasNumericalValue: 1 hasUnit: $unitOne }
		}) { intent { id } }
		acceptResourceOrigin: createIntent(intent: {
			action: "accept" inputOf: $process receiver: $owner hasPointInTime: $creationTime
			resourceInventoriedAs: $resourceOrigin resourceQuantity: { hasNumericalValue: 1 hasUnit: $unitOne }
		}) { intent { id } }
		modifyResourceOrigin: createIntent(intent: {
			action: "modify" outputOf: $process receiver: $owner hasPointInTime: $creationTime
			resourceInventoriedAs: $resourceOrigin resourceQuantity: { hasNumericalValue: 1 hasUnit: $unitOne }
		}) { intent { id } }
	}
"""

@link """
	mutation Link($proposal: ID! $citeIntent: ID! $acceptIntent: ID! $modifyIntent: ID!) {
		proposeCite: proposeIntent(publishedIn: $proposal publishes: $citeIntent) { proposedIntent { id } }
		proposeAccept: proposeIntent(publishedIn: $proposal publishes: $acceptIntent) { proposedIntent { id } }
		proposeModify: proposeIntent(publishedIn: $proposal publishes: $modifyIntent) { proposedIntent { id } }
	}
"""

@accept """
	mutation Accept($id: ID!) {
		acceptContribution(proposalId: $id) {
			proposal { id status }
			citeEvent { id action { id } provider { id } receiver { id } inputOf { id } }
			acceptEvent { id action { id } inputOf { id } }
			modifyEvent { id action { id } outputOf { id } }
		}
	}
"""

@reject """
	mutation Reject($intentCite: ID!, $intentAccept: ID!, $intentModify: ID!) {
		cite: updateIntent(intent: { id: $intentCite finished: true }) { intent { id } }
		accept: updateIntent(intent: { id: $intentAccept finished: true }) { intent { id } }
		modify: updateIntent(intent: { id: $intentModify finished: true }) { intent { id } }
	}
"""

defp propose!(c, proposer, owner, fork, origin) do
	process = Zenflows.VF.Process.Domain.create!(Factory.ctx(proposer), %{name: Factory.str("contribution proposal")}).id
	assert %{data: %{
			"citeResourceForked" => %{"intent" => %{"id" => cite}},
			"acceptResourceOrigin" => %{"intent" => %{"id" => accept}},
			"modifyResourceOrigin" => %{"intent" => %{"id" => modify}}}} =
		run_as!(proposer, @propose_contribution, vars: %{
			"process" => process, "owner" => owner.id, "proposer" => proposer.id,
			"creationTime" => Factory.iso_now(), "resourceForked" => fork,
			"unitOne" => c.unit.id, "resourceOrigin" => origin})
	proposal = Proposal.Domain.create!(Factory.ctx(proposer), %{name: "Contribution to resource", note: "n"}).id
	assert %{data: %{"proposeCite" => _, "proposeAccept" => _, "proposeModify" => _}} =
		run_as!(proposer, @link, vars: %{
			"proposal" => proposal, "citeIntent" => cite, "acceptIntent" => accept, "modifyIntent" => modify})
	%{process: process, proposal: proposal, cite: cite, accept: accept, modify: modify, fork: fork, origin: origin}
end

defp fixture!(c, origin_metadata \\ %{"keep" => "me", "relations" => ["earlier"]}) do
	origin = raise!(c, c.alice, origin_metadata)
	fork = raise!(c, c.bob, %{"relations" => [origin]})
	propose!(c, c.bob, c.alice, fork, origin)
end

defp events_in(process),
	do: Repo.all(from e in EconomicEvent, where: e.input_of_id == ^process or e.output_of_id == ^process)
defp satisfactions(ids),
	do: Repo.all(from s in Satisfaction, where: s.satisfies_id in ^[ids.cite, ids.accept, ids.modify])

test "the owner accepts in one call: events in the proposer's process, satisfactions, ACCEPTED", c do
	ids = fixture!(c)

	assert %{data: %{"acceptContribution" => out}} = run_as!(c.alice, @accept, vars: %{"id" => ids.proposal})
	assert out["proposal"] == %{"id" => ids.proposal, "status" => "ACCEPTED"}
	assert out["citeEvent"]["action"]["id"] == "cite"
	assert out["citeEvent"]["provider"]["id"] == c.bob.id
	assert out["citeEvent"]["receiver"]["id"] == c.alice.id
	assert out["citeEvent"]["inputOf"]["id"] == ids.process
	assert out["acceptEvent"]["inputOf"]["id"] == ids.process
	assert out["modifyEvent"]["outputOf"]["id"] == ids.process

	sats = satisfactions(ids)
	assert length(sats) == 3
	assert MapSet.new(sats, & &1.satisfied_by_event_id) ==
		MapSet.new([out["citeEvent"]["id"], out["acceptEvent"]["id"], out["modifyEvent"]["id"]])
	assert length(events_in(ids.process)) == 3
end

test "the origin's current metadata is kept; the fork is appended to relations once", c do
	ids = fixture!(c)
	assert %{data: %{"acceptContribution" => _}} = run_as!(c.alice, @accept, vars: %{"id" => ids.proposal})
	assert EconomicResource.Domain.one!(ids.origin).metadata ==
		%{"keep" => "me", "relations" => ["earlier", ids.fork]}
end

test "a fork already in relations is not duplicated; no metadata becomes relations only", c do
	ids = fixture!(c, nil)
	assert {:ok, _} = Contribution.accept(Factory.ctx(c.alice), ids.proposal)
	assert EconomicResource.Domain.one!(ids.origin).metadata == %{"relations" => [ids.fork]}

	ids2 = fixture!(c, %{"relations" => []})
	Repo.update_all(from(r in EconomicResource, where: r.id == ^ids2.origin),
		set: [metadata: %{"relations" => [ids2.fork]}])
	assert {:ok, _} = Contribution.accept(Factory.ctx(c.alice), ids2.proposal)
	assert EconomicResource.Domain.one!(ids2.origin).metadata == %{"relations" => [ids2.fork]}
end

test "retrying an accepted proposal returns the same events and writes nothing", c do
	ids = fixture!(c)
	assert {:ok, first} = Contribution.accept(Factory.ctx(c.alice), ids.proposal)
	metadata = EconomicResource.Domain.one!(ids.origin).metadata

	assert {:ok, again} = Contribution.accept(Factory.ctx(c.alice), ids.proposal)
	assert Enum.map([again.cite_event, again.accept_event, again.modify_event], & &1.id) ==
		Enum.map([first.cite_event, first.accept_event, first.modify_event], & &1.id)
	assert length(events_in(ids.process)) == 3
	assert length(satisfactions(ids)) == 3
	assert EconomicResource.Domain.one!(ids.origin).metadata == metadata
end

test "Carol (named nowhere) is FORBIDDEN and nothing is written", c do
	ids = fixture!(c)
	assert %{errors: [err]} = run_as!(c.carol, @accept, vars: %{"id" => ids.proposal})
	assert Map.take(err, [:message, :extensions]) == @forbidden
	assert events_in(ids.process) == []
	assert satisfactions(ids) == []
end

test "the proposer cannot accept their own contribution to Alice's resource", c do
	ids = fixture!(c)
	assert {:error, :forbidden} = Contribution.accept(Factory.ctx(c.bob), ids.proposal)
	assert events_in(ids.process) == []
end

test "the owner who lost control of the origin is FORBIDDEN", c do
	ids = fixture!(c)
	Repo.update_all(from(r in Zenflows.Authz.ResourceControl, where: r.resource_id == ^ids.origin),
		set: [controller_id: c.carol.id])
	assert {:error, :forbidden} = Contribution.accept(Factory.ctx(c.alice), ids.proposal)
	assert events_in(ids.process) == []
end

test "a rejected proposal is a CONFLICT and stays rejected", c do
	ids = fixture!(c)
	assert %{data: %{"cite" => _}} = run_as!(c.alice, @reject, vars: %{
		"intentCite" => ids.cite, "intentAccept" => ids.accept, "intentModify" => ids.modify})

	assert %{errors: [err]} = run_as!(c.alice, @accept, vars: %{"id" => ids.proposal})
	assert err.extensions == %{code: "CONFLICT"}
	assert err.message == "proposal is not pending"
	assert events_in(ids.process) == []
	assert Proposal.Domain.status(ids.proposal) == {:ok, :refused}
end

test "a half-accepted legacy proposal is a CONFLICT, never repaired", c do
	ids = fixture!(c)
	evt = EconomicEvent.Domain.create!(Factory.ctx(c.alice), %{
		action_id: "cite", input_of_id: ids.process, provider_id: c.bob.id, receiver_id: c.alice.id,
		resource_inventoried_as_id: ids.fork,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now()})
	Satisfaction.Domain.create!(Factory.ctx(c.alice), %{satisfies_id: ids.cite, satisfied_by_event_id: evt.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id}})

	assert {:error, :proposal_not_pending} = Contribution.accept(Factory.ctx(c.alice), ids.proposal)
	assert length(events_in(ids.process)) == 1
end

test "a proposal that is not a contribution is BAD_USER_INPUT", c do
	item = raise!(c, c.bob)
	proposal = Proposal.Domain.create!(Factory.ctx(c.bob), %{name: "sale"}).id
	intent = Intent.Domain.create!(Factory.ctx(c.bob), %{action_id: "transfer", provider_id: c.bob.id,
		resource_inventoried_as_id: item, resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id}})
	Zenflows.VF.ProposedIntent.Domain.create!(Factory.ctx(c.bob), %{published_in_id: proposal, publishes_id: intent.id})

	assert %{errors: [err]} = run_as!(c.bob, @accept, vars: %{"id" => proposal})
	assert err.extensions == %{code: "BAD_USER_INPUT"}
	assert err.message == "not a contribution proposal"
end

test "an unknown proposal is BAD_USER_INPUT", c do
	assert {:error, :not_contribution_proposal} = Contribution.accept(Factory.ctx(c.alice), ID.gen())
end

test "a failure after the first event rolls everything back", c do
	ids = fixture!(c)
	# The accept event must take the whole on-hand quantity; an intent asking
	# for 2 makes it fail after the cite event was inserted.
	Repo.update_all(from(i in Intent, where: i.id == ^ids.accept),
		set: [resource_quantity_has_numerical_value: Decimal.new(2)])

	assert {:error, _} = Contribution.accept(Factory.ctx(c.alice), ids.proposal)
	assert events_in(ids.process) == []
	assert satisfactions(ids) == []
	assert EconomicResource.Domain.one!(ids.origin).metadata == %{"keep" => "me", "relations" => ["earlier"]}
	assert Proposal.Domain.status(ids.proposal) == {:ok, :pending}
end
end
