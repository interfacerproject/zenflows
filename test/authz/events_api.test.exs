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

defmodule ZenflowsTest.Authz.EventsAPI do
use ZenflowsTest.Help.AbsinCase, async: false

alias Zenflows.VF.{EconomicEvent, EconomicResource}

@forbidden %{message: "forbidden", extensions: %{code: "FORBIDDEN"}}

setup do
	prev = Application.get_env(:zenflows, Zenflows.Authz)
	on_exit(fn -> Application.put_env(:zenflows, Zenflows.Authz, prev) end)
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person),
		unit: Factory.insert!(:unit), spec: Factory.insert!(:resource_specification)}
end

defp raise!(c, owner) do
	EconomicEvent.Domain.create!(Factory.ctx(owner), %{
		action_id: "raise", provider_id: owner.id, receiver_id: owner.id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: Factory.str("res")})
end

test "acceptProposal-shaped document succeeds for the owner", c do
	origin = raise!(c, c.alice).resource_inventoried_as_id
	fork = raise!(c, c.bob).resource_inventoried_as_id
	process = Factory.insert_process!(c.alice).id
	assert %{data: %{"cite" => %{"economicEvent" => %{"id" => _}},
			"accept" => %{"economicEvent" => %{"id" => _}},
			"modify" => %{"economicEvent" => %{"id" => _}}}} =
		run_as!(c.alice, """
			mutation ($process: ID!, $owner: ID!, $proposer: ID!, $unit: ID!, $fork: ID!, $origin: ID!, $now: DateTime!) {
				cite: createEconomicEvent(event: {action: "cite", inputOf: $process, provider: $proposer, receiver: $owner,
					resourceInventoriedAs: $fork, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}, hasPointInTime: $now}) { economicEvent { id } }
				accept: createEconomicEvent(event: {action: "accept", inputOf: $process, provider: $owner, receiver: $owner,
					resourceInventoriedAs: $origin, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}, hasPointInTime: $now}) { economicEvent { id } }
				modify: createEconomicEvent(event: {action: "modify", outputOf: $process, provider: $owner, receiver: $owner,
					resourceInventoriedAs: $origin, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}, hasPointInTime: $now}) { economicEvent { id } }
			}
		""", vars: %{"process" => process, "owner" => c.alice.id, "proposer" => c.bob.id,
			"unit" => c.unit.id, "fork" => fork, "origin" => origin, "now" => Factory.iso_now()})
end

test "claim-shaped document succeeds for a listed agent", c do
	losh = Factory.insert!(:person)
	Application.put_env(:zenflows, Zenflows.Authz,
		Keyword.put(Application.get_env(:zenflows, Zenflows.Authz), :claimable_agents, [losh.id]))
	res = raise!(c, losh).resource_inventoried_as_id
	assert %{data: %{"createEconomicEvent" => %{"economicEvent" => %{"toResourceInventoriedAs" => %{"id" => _}}}}} =
		run_as!(c.bob, """
			mutation ($res: ID!, $losh: ID!, $agent: ID!, $unit: ID!, $now: DateTime!) {
				createEconomicEvent(event: {resourceInventoriedAs: $res, action: "transfer", provider: $losh, receiver: $agent,
					hasPointInTime: $now, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}},
					newInventoriedResource: {name: "claimed"}) {
					economicEvent { id toResourceInventoriedAs { id } }
				}
			}
		""", vars: %{"res" => res, "losh" => losh.id, "agent" => c.bob.id, "unit" => c.unit.id, "now" => Factory.iso_now()})
end

test "Bob cannot transfer Alice's resource to himself over GraphQL", c do
	res = raise!(c, c.alice).resource_inventoried_as_id
	assert %{data: nil, errors: [err]} =
		run_as!(c.bob, """
			mutation ($res: ID!, $alice: ID!, $bob: ID!, $unit: ID!, $now: DateTime!) {
				createEconomicEvent(event: {resourceInventoriedAs: $res, action: "transfer", provider: $alice, receiver: $bob,
					hasPointInTime: $now, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}},
					newInventoriedResource: {name: "mine"}) { economicEvent { id } }
			}
		""", vars: %{"res" => res, "alice" => c.alice.id, "bob" => c.bob.id, "unit" => c.unit.id, "now" => Factory.iso_now()})
	assert Map.take(err, [:message, :extensions]) == @forbidden
	assert EconomicResource.Domain.one!(res).primary_accountable_id == c.alice.id
end

test "updateEconomicEvent: provider may edit the note, a stranger may not", c do
	evt = raise!(c, c.alice)
	doc = """
		mutation ($id: ID!, $note: String!) {
			updateEconomicEvent(event: {id: $id, note: $note}) { economicEvent { id note } }
		}
	"""
	assert %{data: nil, errors: [err]} =
		run_as!(c.bob, doc, vars: %{"id" => evt.id, "note" => "edited"})
	assert Map.take(err, [:message, :extensions]) == @forbidden
	assert EconomicEvent.Domain.one!(evt.id).note == evt.note
	assert %{data: %{"updateEconomicEvent" => %{"economicEvent" => %{"note" => "by alice"}}}} =
		run_as!(c.alice, doc, vars: %{"id" => evt.id, "note" => "by alice"})
end
end
