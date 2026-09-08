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

defmodule ZenflowsTest.VF.Proposal.FilterScoping do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.DB.Page
alias Zenflows.VF.EconomicResource.Domain, as: ResourceDomain
alias Zenflows.VF.Proposal.Domain

defp insert_resource!(opts) do
	agent = Factory.insert!(:agent)
	%{resource_inventoried_as_id: res_id} =
		Zenflows.VF.EconomicEvent.Domain.create!(%{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_classified_as: Factory.str_list("uri"),
			resource_conforms_to_id: opts[:conforms_to_id],
			resource_quantity: %{
				has_numerical_value: Factory.decimald(),
				has_unit_id: Factory.insert!(:unit).id,
			},
			has_point_in_time: Factory.now(),
		}, %{name: opts[:name], note: opts[:note] || Factory.str("note")})
	ResourceDomain.one!(res_id)
end

# A proposal whose sole primary intent is inventoried as `resource`.
defp insert_proposal_for!(resource) do
	proposal = Factory.insert!(:proposal)
	int = Factory.insert!(:intent, resource_inventoried_as_id: resource.id)
	Factory.insert!(:proposed_intent,
		published_in: proposal, publishes: int, reciprocal: false)
	proposal
end

defp result_ids(filter) do
	{:ok, results} = Domain.all(Page.new(%{filter: filter}))
	MapSet.new(results, & &1.id)
end

describe "or_primary_intents_resource_inventoried_as_* is ANDed with the other filters" do
	test "a name match whose primary intent has the wrong conforms_to is excluded" do
		spec_a = Factory.insert!(:resource_specification).id
		spec_b = Factory.insert!(:resource_specification).id

		match_prop =
			insert_proposal_for!(insert_resource!(conforms_to_id: spec_a, name: "solar charger prop"))
		wrong_spec_prop =
			insert_proposal_for!(insert_resource!(conforms_to_id: spec_b, name: "solar charger prop"))

		ids = result_ids(%{
			primary_intents_resource_inventoried_as_conforms_to: [spec_a],
			or_primary_intents_resource_inventoried_as_name: "solar",
			or_primary_intents_resource_inventoried_as_note: "solar",
		})

		assert MapSet.member?(ids, match_prop.id)
		refute MapSet.member?(ids, wrong_spec_prop.id),
			"proposal matching or_name but NOT the conforms_to filter must be excluded"
	end

	test "or_name / or_note still behave as an OR internally" do
		spec = Factory.insert!(:resource_specification).id

		by_name = insert_proposal_for!(insert_resource!(conforms_to_id: spec, name: "solar kit",    note: "x"))
		by_note = insert_proposal_for!(insert_resource!(conforms_to_id: spec, name: "x",            note: "a charger"))
		neither = insert_proposal_for!(insert_resource!(conforms_to_id: spec, name: "x",            note: "x"))

		ids = result_ids(%{
			primary_intents_resource_inventoried_as_conforms_to: [spec],
			or_primary_intents_resource_inventoried_as_name: "solar",
			or_primary_intents_resource_inventoried_as_note: "charger",
		})

		assert MapSet.member?(ids, by_name.id)
		assert MapSet.member?(ids, by_note.id)
		refute MapSet.member?(ids, neither.id)
	end
end
end
