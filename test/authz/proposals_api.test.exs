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

defmodule ZenflowsTest.Authz.ProposalsAPI do
@moduledoc """
GraphQL-level tests of the SDK's proposal flows (the interfacer-client
`ResourceClient.proposeContribution/acceptProposal/rejectProposal`
sequence, plus a plain sale-proposal flow), using the exact documents
from `interfacer-client/src/graphql/operations.ts`, through
`AbsinCase.run_as!/3`.
"""
use ZenflowsTest.Help.AbsinCase, async: false

alias Zenflows.VF.EconomicEvent

@forbidden %{message: "forbidden", extensions: %{code: "FORBIDDEN"}}

setup do
	%{
		alice: Factory.insert!(:person),
		bob: Factory.insert!(:person),
		carol: Factory.insert!(:person),
		unit: Factory.insert!(:unit),
		spec: Factory.insert!(:resource_specification),
		currency: Factory.insert!(:resource_specification),
	}
end

# Like `test/authz/events_api.test.exs`'s `raise!/2`: `owner` raises
# their own resource.
defp raise!(c, owner) do
	EconomicEvent.Domain.create!(Factory.ctx(owner), %{
		action_id: "raise", provider_id: owner.id, receiver_id: owner.id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: Factory.str("res")})
end

@create_process """
	mutation CreateProcess($name: String!) {
		createProcess(process: { name: $name }) { process { id } }
	}
"""

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

@create_proposal """
	mutation CreateProposal($name: String!, $note: String!) {
		createProposal(proposal: { name: $name, note: $note }) { proposal { id } }
	}
"""

@link_contribution_proposal_intent """
	mutation LinkContributionAndProposalAndIntent(
		$proposal: ID! $citeIntent: ID! $acceptIntent: ID! $modifyIntent: ID!
	) {
		proposeCite: proposeIntent(publishedIn: $proposal publishes: $citeIntent) { proposedIntent { id } }
		proposeAccept: proposeIntent(publishedIn: $proposal publishes: $acceptIntent) { proposedIntent { id } }
		proposeModify: proposeIntent(publishedIn: $proposal publishes: $modifyIntent) { proposedIntent { id } }
	}
"""

@accept_proposal """
	mutation acceptProposal(
		$process: ID! $owner: ID! $proposer: ID! $unitOne: ID!
		$resourceForked: ID! $resourceOrigin: ID! $creationTime: DateTime! $metadata: JSONObject
	) {
		cite: createEconomicEvent(event: {
			action: "cite" inputOf: $process provider: $proposer receiver: $owner
			resourceInventoriedAs: $resourceForked resourceQuantity: { hasNumericalValue: 1 hasUnit: $unitOne }
			hasPointInTime: $creationTime
		}) { economicEvent { id } }
		accept: createEconomicEvent(event: {
			action: "accept" inputOf: $process provider: $owner receiver: $owner
			resourceInventoriedAs: $resourceOrigin resourceQuantity: { hasNumericalValue: 1 hasUnit: $unitOne }
			hasPointInTime: $creationTime
		}) { economicEvent { id } }
		modify: createEconomicEvent(event: {
			action: "modify" outputOf: $process provider: $owner receiver: $owner
			resourceInventoriedAs: $resourceOrigin resourceQuantity: { hasNumericalValue: 1 hasUnit: $unitOne }
			hasPointInTime: $creationTime resourceMetadata: $metadata
		}) { economicEvent { id } }
	}
"""

@satisfy_intents """
	mutation satisfyIntents(
		$unitOne: ID! $intentCited: ID! $intentAccepted: ID! $intentModify: ID!
		$eventCite: ID! $eventAccept: ID! $eventModify: ID!
	) {
		cite: createSatisfaction(satisfaction: {
			satisfies: $intentCited satisfiedByEvent: $eventCite resourceQuantity: { hasNumericalValue: 1 hasUnit: $unitOne }
		}) { satisfaction { id } }
		accept: createSatisfaction(satisfaction: {
			satisfies: $intentAccepted satisfiedByEvent: $eventAccept resourceQuantity: { hasNumericalValue: 1 hasUnit: $unitOne }
		}) { satisfaction { id } }
		modify: createSatisfaction(satisfaction: {
			satisfies: $intentModify satisfiedByEvent: $eventModify resourceQuantity: { hasNumericalValue: 1 hasUnit: $unitOne }
		}) { satisfaction { id } }
	}
"""

@reject_proposal """
	mutation rejectProposal($intentCite: ID!, $intentAccept: ID!, $intentModify: ID!) {
		cite: updateIntent(intent: { id: $intentCite finished: true }) { intent { id } }
		accept: updateIntent(intent: { id: $intentAccept finished: true }) { intent { id } }
		modify: updateIntent(intent: { id: $intentModify finished: true }) { intent { id } }
	}
"""

@create_intent_sale """
	mutation CreateIntent($agent: ID!, $resource: ID!, $oneUnit: ID!, $currency: ID!, $howMuch: Decimal!) {
		item: createIntent(intent: { name: "project" action: "transfer" provider: $agent
			resourceInventoriedAs: $resource resourceQuantity: { hasNumericalValue: 1 hasUnit: $oneUnit }
		}) { intent { id } }
		payment: createIntent(intent: { name: "payment" action: "transfer" receiver: $agent
			resourceConformsTo: $currency resourceQuantity: { hasNumericalValue: $howMuch hasUnit: $oneUnit }
		}) { intent { id } }
	}
"""

@link_proposal_and_intent """
	mutation LinkProposalAndIntent($proposal: ID!, $item: ID!, $payment: ID!) {
		linkItem: proposeIntent(publishedIn: $proposal publishes: $item reciprocal: false) { proposedIntent { id } }
		linkPayment: proposeIntent(publishedIn: $proposal publishes: $payment reciprocal: true) { proposedIntent { id } }
	}
"""

# Runs the whole `proposeContribution` sequence as `proposer`, returning
# the ids the SDK threads from one call to the next.
defp propose_contribution!(c, proposer, owner, resource_forked, resource_origin) do
	assert %{data: %{"createProcess" => %{"process" => %{"id" => process}}}} =
		run_as!(proposer, @create_process, vars: %{"name" => Factory.str("contribution proposal")})

	assert %{data: %{
			"citeResourceForked" => %{"intent" => %{"id" => cite}},
			"acceptResourceOrigin" => %{"intent" => %{"id" => accept}},
			"modifyResourceOrigin" => %{"intent" => %{"id" => modify}}}} =
		run_as!(proposer, @propose_contribution, vars: %{
			"process" => process, "owner" => owner.id, "proposer" => proposer.id,
			"creationTime" => Factory.iso_now(), "resourceForked" => resource_forked,
			"unitOne" => c.unit.id, "resourceOrigin" => resource_origin})

	assert %{data: %{"createProposal" => %{"proposal" => %{"id" => proposal}}}} =
		run_as!(proposer, @create_proposal,
			vars: %{"name" => Factory.str("Contribution to resource"), "note" => Factory.str("note")})

	assert %{data: %{
			"proposeCite" => %{"proposedIntent" => %{"id" => _}},
			"proposeAccept" => %{"proposedIntent" => %{"id" => _}},
			"proposeModify" => %{"proposedIntent" => %{"id" => _}}}} =
		run_as!(proposer, @link_contribution_proposal_intent,
			vars: %{"proposal" => proposal, "citeIntent" => cite, "acceptIntent" => accept, "modifyIntent" => modify})

	%{process: process, proposal: proposal, cite_intent: cite, accept_intent: accept, modify_intent: modify}
end

test "proposeContribution as Bob succeeds: his process, intents, proposal, and links", c do
	origin = raise!(c, c.alice).resource_inventoried_as_id
	fork = raise!(c, c.bob).resource_inventoried_as_id

	ids = propose_contribution!(c, c.bob, c.alice, fork, origin)

	assert {:ok, _} = Zenflows.DB.ID.cast(ids.process)
	assert {:ok, _} = Zenflows.DB.ID.cast(ids.proposal)
end

test "acceptProposal as Alice succeeds: her new process, cite/accept/modify events, satisfactions", c do
	origin = raise!(c, c.alice).resource_inventoried_as_id
	fork = raise!(c, c.bob).resource_inventoried_as_id

	ids = propose_contribution!(c, c.bob, c.alice, fork, origin)

	assert %{data: %{"createProcess" => %{"process" => %{"id" => accept_process}}}} =
		run_as!(c.alice, @create_process, vars: %{"name" => Factory.str("accept contribution")})

	assert %{data: %{
			"cite" => %{"economicEvent" => %{"id" => evt_cite}},
			"accept" => %{"economicEvent" => %{"id" => evt_accept}},
			"modify" => %{"economicEvent" => %{"id" => evt_modify}}}} =
		run_as!(c.alice, @accept_proposal, vars: %{
			"process" => accept_process, "owner" => c.alice.id, "proposer" => c.bob.id,
			"unitOne" => c.unit.id, "resourceForked" => fork, "resourceOrigin" => origin,
			"creationTime" => Factory.iso_now()})

	assert %{data: %{
			"cite" => %{"satisfaction" => %{"id" => _}},
			"accept" => %{"satisfaction" => %{"id" => _}},
			"modify" => %{"satisfaction" => %{"id" => _}}}} =
		run_as!(c.alice, @satisfy_intents, vars: %{
			"unitOne" => c.unit.id,
			"intentCited" => ids.cite_intent, "intentAccepted" => ids.accept_intent, "intentModify" => ids.modify_intent,
			"eventCite" => evt_cite, "eventAccept" => evt_accept, "eventModify" => evt_modify})
end

test "interfacer-gui acceptProposal (pages/proposal/[id].tsx): events on the proposer's process, then satisfyIntents", c do
	origin = raise!(c, c.alice).resource_inventoried_as_id
	fork = raise!(c, c.bob).resource_inventoried_as_id

	ids = propose_contribution!(c, c.bob, c.alice, fork, origin)

	# The GUI passes `cite.inputOf?.id || cite.outputOf?.id`: Bob's
	# process, which Alice does not control; she is invited by the
	# unfinished accept/modify intents naming her as receiver.
	assert %{data: %{
			"cite" => %{"economicEvent" => %{"id" => evt_cite}},
			"accept" => %{"economicEvent" => %{"id" => evt_accept}},
			"modify" => %{"economicEvent" => %{"id" => evt_modify}}}} =
		run_as!(c.alice, @accept_proposal, vars: %{
			"process" => ids.process, "owner" => c.alice.id, "proposer" => c.bob.id,
			"unitOne" => c.unit.id, "resourceForked" => fork, "resourceOrigin" => origin,
			"creationTime" => Factory.iso_now(),
			"metadata" => Jason.encode!(%{"relations" => [fork]})})

	assert %{data: %{
			"cite" => %{"satisfaction" => %{"id" => _}},
			"accept" => %{"satisfaction" => %{"id" => _}},
			"modify" => %{"satisfaction" => %{"id" => _}}}} =
		run_as!(c.alice, @satisfy_intents, vars: %{
			"unitOne" => c.unit.id,
			"intentCited" => ids.cite_intent, "intentAccepted" => ids.accept_intent, "intentModify" => ids.modify_intent,
			"eventCite" => evt_cite, "eventAccept" => evt_accept, "eventModify" => evt_modify})
end

test "interfacer-gui acceptProposal by Carol (named nowhere) on the proposer's process: FORBIDDEN", c do
	origin = raise!(c, c.alice).resource_inventoried_as_id
	fork = raise!(c, c.bob).resource_inventoried_as_id
	ids = propose_contribution!(c, c.bob, c.alice, fork, origin)

	assert %{errors: [err | _]} =
		run_as!(c.carol, @accept_proposal, vars: %{
			"process" => ids.process, "owner" => c.carol.id, "proposer" => c.bob.id,
			"unitOne" => c.unit.id, "resourceForked" => fork, "resourceOrigin" => origin,
			"creationTime" => Factory.iso_now()})
	assert Map.take(err, [:message, :extensions]) == @forbidden
end

test "rejectProposal as Alice: all three intents (incl. the cite intent) finish, no error", c do
	origin = raise!(c, c.alice).resource_inventoried_as_id
	fork = raise!(c, c.bob).resource_inventoried_as_id

	ids = propose_contribution!(c, c.bob, c.alice, fork, origin)

	assert %{data: %{
			"cite" => %{"intent" => %{"id" => _}},
			"accept" => %{"intent" => %{"id" => _}},
			"modify" => %{"intent" => %{"id" => _}}}} =
		run_as!(c.alice, @reject_proposal, vars: %{
			"intentCite" => ids.cite_intent, "intentAccept" => ids.accept_intent, "intentModify" => ids.modify_intent})

	assert Zenflows.VF.Intent.Domain.one!(ids.cite_intent).finished
	assert Zenflows.VF.Intent.Domain.one!(ids.accept_intent).finished
	assert Zenflows.VF.Intent.Domain.one!(ids.modify_intent).finished
end

test "Carol cannot run rejectProposal on Bob's and Alice's intents: FORBIDDEN, intents unchanged", c do
	origin = raise!(c, c.alice).resource_inventoried_as_id
	fork = raise!(c, c.bob).resource_inventoried_as_id

	ids = propose_contribution!(c, c.bob, c.alice, fork, origin)

	assert %{data: nil, errors: [err]} =
		run_as!(c.carol, @reject_proposal, vars: %{
			"intentCite" => ids.cite_intent, "intentAccept" => ids.accept_intent, "intentModify" => ids.modify_intent})
	assert Map.take(err, [:message, :extensions]) == @forbidden

	refute Zenflows.VF.Intent.Domain.one!(ids.cite_intent).finished
	refute Zenflows.VF.Intent.Domain.one!(ids.accept_intent).finished
	refute Zenflows.VF.Intent.Domain.one!(ids.modify_intent).finished
end

test "a sale proposal as the seller: createProposal, item/payment createIntent, linkProposalAndIntent", c do
	item = raise!(c, c.bob).resource_inventoried_as_id

	assert %{data: %{"createProposal" => %{"proposal" => %{"id" => proposal}}}} =
		run_as!(c.bob, @create_proposal,
			vars: %{"name" => Factory.str("sale"), "note" => Factory.str("note")})

	assert %{data: %{
			"item" => %{"intent" => %{"id" => item_intent}},
			"payment" => %{"intent" => %{"id" => payment_intent}}}} =
		run_as!(c.bob, @create_intent_sale, vars: %{
			"agent" => c.bob.id, "resource" => item, "oneUnit" => c.unit.id,
			"currency" => c.currency.id, "howMuch" => Factory.decimal()})

	assert %{data: %{
			"linkItem" => %{"proposedIntent" => %{"id" => _}},
			"linkPayment" => %{"proposedIntent" => %{"id" => _}}}} =
		run_as!(c.bob, @link_proposal_and_intent,
			vars: %{"proposal" => proposal, "item" => item_intent, "payment" => payment_intent})
end
end
