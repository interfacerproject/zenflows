# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule ZenflowsTest.VF.EconomicEvent.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{id: agent_id} = Factory.insert!(:agent)
	%{
		params: %{
			action_id: "raise",
			provider_id: agent_id,
			receiver_id: agent_id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity_has_unit_id: Factory.insert!(:unit).id,
			resource_quantity_has_numerical_value: Factory.float(),
			has_end: DateTime.utc_now(),
		},
		inserted: %{},
	}
end

describe "Query" do
	#test "economicEvent()", %{inserted: eco_evt} do
	#	assert %{data: %{"economicEvent" => data}} =
	#		query!("""
	#			economicEvent(id: "#{eco_evt.id}") {
	#				id
	#				note
	#				action { id label resourceEffect onhandEffect inputOutput pairsWith }
	#				resourceQuantity {
	#					hasUnit { id }
	#					hasNumericalValue
	#				}
	#				effortQuantity {
	#					hasUnit { id }
	#					hasNumericalValue
	#				}
	#				economicEventResource { id }
	#				recipeInputOf { id }
	#				recipeOutputOf { id }
	#				recipeClauseOf { id }
	#			}
	#		""")

	#	assert data["id"] == eco_evt.id
	#	assert data["note"] == eco_evt.note
	#	assert data["action"]["id"] == action.id
	#	assert data["action"]["label"] == action.label
	#	assert data["action"]["resourceEffect"] == action.resource_effect
	#	assert data["action"]["onhandEffect"] == action.onhand_effect
	#	assert data["action"]["inputOutput"] == action.input_output
	#	assert data["action"]["pairsWith"] == action.pairs_with
	#	assert data["resourceQuantity"]["hasUnit"]["id"] == res_qty.has_unit_id
	#	assert data["resourceQuantity"]["hasNumericalValue"] == res_qty.has_numerical_value
	#	assert data["effortQuantity"]["hasUnit"]["id"] == eff_qty.has_unit_id
	#	assert data["effortQuantity"]["hasNumericalValue"] == eff_qty.has_numerical_value
	#	assert data["economicEventResource"]["id"] == eco_evt_res.id
	#	assert data["recipeInputOf"]["id"] == rec_in_of.id
	#	assert data["recipeOutputOf"]["id"] == rec_out_of.id
	#	assert data["recipeClauseOf"]["id"] == rec_clause_of.id
	#end
end

describe "Mutation" do
	test "createEconomicEvent()", %{params: params} do
		assert %{data: %{"createEconomicEvent" => %{"economicEvent" => data}}} =
			mutation!("""
				createEconomicEvent(
					event: {
						action: "raise"
						provider: "#{params.provider_id}"
						receiver: "#{params.receiver_id}"
						resourceConformsTo: "#{params.resource_conforms_to_id}"
						resourceQuantity: {
							hasUnit: "#{params.resource_quantity_has_unit_id}"
							hasNumericalValue: #{params.resource_quantity_has_numerical_value}
						}
						hasEnd: "#{params.has_end}"
					}
					newInventoriedResource: {
						name: "yo/"
					}
				) {
					economicEvent {
						id
						action {id}
						provider {id}
						receiver {id}
						resourceConformsTo {id}
						resourceQuantity {
							hasUnit {id}
							hasNumericalValue
						}
						resourceInventoriedAs {
							id
							name
						}
						hasEnd
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
	end

	#test "updateEconomicEvent()", %{params: params, inserted: eco_evt} do
	#	%{
	#		action_id: action_id,
	#		resource_quantity: res_qty,
	#		effort_quantity: eff_qty,
	#		inserted_resource_id: eco_evt_res_id,
	#		recipe_input_of_id: rec_in_of_id,
	#		recipe_output_of_id: rec_out_of_id,
	#		recipe_clause_of_id: rec_clause_of_id,
	#	} = params

	#	assert %{data: %{"updateEconomicEvent" => %{"economicEvent" => data}}} =
	#		mutation!("""
	#			updateEconomicEvent(economicEvent: {
	#				id: "#{eco_evt.id}"
	#				note: "#{params.note}"
	#				action: "#{action_id}"
	#				resourceQuantity: {
	#					hasUnit: "#{res_qty.has_unit_id}"
	#					hasNumericalValue: #{res_qty.has_numerical_value}
	#				}
	#				effortQuantity: {
	#					hasUnit: "#{eff_qty.has_unit_id}"
	#					hasNumericalValue: #{eff_qty.has_numerical_value}
	#				}
	#				economicEventResource: "#{eco_evt_res_id}"
	#				recipeInputOf: "#{rec_in_of_id}"
	#				recipeOutputOf: "#{rec_out_of_id}"
	#				recipeClauseOf: "#{rec_clause_of_id}"
	#			}) {
	#				economicEvent {
	#					id
	#					note
	#					action { id label resourceEffect onhandEffect inputOutput pairsWith }
	#					resourceQuantity {
	#						hasUnit { id }
	#						hasNumericalValue
	#					}
	#					effortQuantity {
	#						hasUnit { id }
	#						hasNumericalValue
	#					}
	#					economicEventResource { id }
	#					recipeInputOf { id }
	#					recipeOutputOf { id }
	#					recipeClauseOf { id }
	#				}
	#			}
	#		""")

	#	assert data["id"] == eco_evt.id
	#	assert data["note"] == params.note
	#	assert data["action"]["id"] == action_id
	#	assert data["resourceQuantity"]["hasUnit"]["id"] == res_qty.has_unit_id
	#	assert data["resourceQuantity"]["hasNumericalValue"] == res_qty.has_numerical_value
	#	assert data["effortQuantity"]["hasUnit"]["id"] == eff_qty.has_unit_id
	#	assert data["effortQuantity"]["hasNumericalValue"] == eff_qty.has_numerical_value
	#	assert data["economicEventResource"]["id"] == eco_evt_res_id
	#	assert data["recipeInputOf"]["id"] == rec_in_of_id
	#	assert data["recipeOutputOf"]["id"] == rec_out_of_id
	#	assert data["recipeClauseOf"]["id"] == rec_clause_of_id
	#end
end
end
