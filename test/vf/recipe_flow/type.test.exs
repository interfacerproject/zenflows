defmodule ZenflowsTest.VF.RecipeFlow.Type do
use ZenflowsTest.Help.AbsinCase, async: true

alias Zenflows.VF.RecipeFlow.Domain

setup do
	%{
		params: %{
			note: Factory.uniq("some note"),
			action_id: Factory.build(:action_id),
			recipe_input_of_id: Factory.insert!(:recipe_process).id,
			recipe_output_of_id: Factory.insert!(:recipe_process).id,
			recipe_flow_resource_id: Factory.insert!(:recipe_resource).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			effort_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			recipe_clause_of_id: Factory.insert!(:recipe_exchange).id,
		},
		recipe_flow:
			Factory.insert!(:recipe_flow)
			|> Domain.preload(:action)
			|> Domain.preload(:resource_quantity)
			|> Domain.preload(:effort_quantity)
			|> Domain.preload(:recipe_flow_resource)
			|> Domain.preload(:recipe_input_of)
			|> Domain.preload(:recipe_output_of)
			|> Domain.preload(:recipe_clause_of)
	}
end

describe "Query" do
	test "recipeFlow()", %{recipe_flow: rec_flow} do
		%{
			action: action,
			resource_quantity: res_qty,
			effort_quantity: eff_qty,
			recipe_flow_resource: rec_flow_res,
			recipe_input_of: rec_in_of,
			recipe_output_of: rec_out_of,
			recipe_clause_of: rec_clause_of,
		} = rec_flow

		assert %{data: %{"recipeFlow" => data}} =
			query!("""
				recipeFlow(id: "#{rec_flow.id}") {
					id
					note
					action { id label resourceEffect onhandEffect inputOutput pairsWith }
					resourceQuantity {
						hasUnit { id }
						hasNumericalValue
					}
					effortQuantity {
						hasUnit { id }
						hasNumericalValue
					}
					recipeFlowResource { id }
					recipeInputOf { id }
					recipeOutputOf { id }
					recipeClauseOf { id }
				}
			""")

		assert data["id"] == rec_flow.id
		assert data["note"] == rec_flow.note
		assert data["action"]["id"] == action.id
		assert data["action"]["label"] == action.label
		assert data["action"]["resourceEffect"] == action.resource_effect
		assert data["action"]["onhandEffect"] == action.onhand_effect
		assert data["action"]["inputOutput"] == action.input_output
		assert data["action"]["pairsWith"] == action.pairs_with
		assert data["resourceQuantity"]["hasUnit"]["id"] == res_qty.has_unit_id
		assert data["resourceQuantity"]["hasNumericalValue"] == res_qty.has_numerical_value
		assert data["effortQuantity"]["hasUnit"]["id"] == eff_qty.has_unit_id
		assert data["effortQuantity"]["hasNumericalValue"] == eff_qty.has_numerical_value
		assert data["recipeFlowResource"]["id"] == rec_flow_res.id
		assert data["recipeInputOf"]["id"] == rec_in_of.id
		assert data["recipeOutputOf"]["id"] == rec_out_of.id
		assert data["recipeClauseOf"]["id"] == rec_clause_of.id
	end
end

describe "Mutation" do
	test "createRecipeFlow()", %{params: params} do
		%{
			action_id: action_id,
			resource_quantity: res_qty,
			effort_quantity: eff_qty,
			recipe_flow_resource_id: rec_flow_res_id,
			recipe_input_of_id: rec_in_of_id,
			recipe_output_of_id: rec_out_of_id,
			recipe_clause_of_id: rec_clause_of_id,
		} = params

		assert %{data: %{"createRecipeFlow" => %{"recipeFlow" => data}}} =
			mutation!("""
				createRecipeFlow(recipeFlow: {
					note: "#{params.note}"
					action: "#{action_id}"
					resourceQuantity: {
						hasUnit: "#{res_qty.has_unit_id}"
						hasNumericalValue: #{res_qty.has_numerical_value}
					}
					effortQuantity: {
						hasUnit: "#{eff_qty.has_unit_id}"
						hasNumericalValue: #{eff_qty.has_numerical_value}
					}
					recipeFlowResource: "#{rec_flow_res_id}"
					recipeInputOf: "#{rec_in_of_id}"
					recipeOutputOf: "#{rec_out_of_id}"
					recipeClauseOf: "#{rec_clause_of_id}"
				}) {
					recipeFlow {
						id
						note
						action { id label resourceEffect onhandEffect inputOutput pairsWith }
						resourceQuantity {
							hasUnit { id }
							hasNumericalValue
						}
						effortQuantity {
							hasUnit { id }
							hasNumericalValue
						}
						recipeFlowResource { id }
						recipeInputOf { id }
						recipeOutputOf { id }
						recipeClauseOf { id }
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["note"] == params.note
		assert data["action"]["id"] == action_id
		assert data["resourceQuantity"]["hasUnit"]["id"] == res_qty.has_unit_id
		assert data["resourceQuantity"]["hasNumericalValue"] == res_qty.has_numerical_value
		assert data["effortQuantity"]["hasUnit"]["id"] == eff_qty.has_unit_id
		assert data["effortQuantity"]["hasNumericalValue"] == eff_qty.has_numerical_value
		assert data["recipeFlowResource"]["id"] == rec_flow_res_id
		assert data["recipeInputOf"]["id"] == rec_in_of_id
		assert data["recipeOutputOf"]["id"] == rec_out_of_id
		assert data["recipeClauseOf"]["id"] == rec_clause_of_id
	end

	test "updateRecipeFlow()", %{params: params, recipe_flow: rec_flow} do
		%{
			action_id: action_id,
			resource_quantity: res_qty,
			effort_quantity: eff_qty,
			recipe_flow_resource_id: rec_flow_res_id,
			recipe_input_of_id: rec_in_of_id,
			recipe_output_of_id: rec_out_of_id,
			recipe_clause_of_id: rec_clause_of_id,
		} = params

		assert %{data: %{"updateRecipeFlow" => %{"recipeFlow" => data}}} =
			mutation!("""
				updateRecipeFlow(recipeFlow: {
					id: "#{rec_flow.id}"
					note: "#{params.note}"
					action: "#{action_id}"
					resourceQuantity: {
						hasUnit: "#{res_qty.has_unit_id}"
						hasNumericalValue: #{res_qty.has_numerical_value}
					}
					effortQuantity: {
						hasUnit: "#{eff_qty.has_unit_id}"
						hasNumericalValue: #{eff_qty.has_numerical_value}
					}
					recipeFlowResource: "#{rec_flow_res_id}"
					recipeInputOf: "#{rec_in_of_id}"
					recipeOutputOf: "#{rec_out_of_id}"
					recipeClauseOf: "#{rec_clause_of_id}"
				}) {
					recipeFlow {
						id
						note
						action { id label resourceEffect onhandEffect inputOutput pairsWith }
						resourceQuantity {
							hasUnit { id }
							hasNumericalValue
						}
						effortQuantity {
							hasUnit { id }
							hasNumericalValue
						}
						recipeFlowResource { id }
						recipeInputOf { id }
						recipeOutputOf { id }
						recipeClauseOf { id }
					}
				}
			""")

		assert data["id"] == rec_flow.id
		assert data["note"] == params.note
		assert data["action"]["id"] == action_id
		assert data["resourceQuantity"]["hasUnit"]["id"] == res_qty.has_unit_id
		assert data["resourceQuantity"]["hasNumericalValue"] == res_qty.has_numerical_value
		assert data["effortQuantity"]["hasUnit"]["id"] == eff_qty.has_unit_id
		assert data["effortQuantity"]["hasNumericalValue"] == eff_qty.has_numerical_value
		assert data["recipeFlowResource"]["id"] == rec_flow_res_id
		assert data["recipeInputOf"]["id"] == rec_in_of_id
		assert data["recipeOutputOf"]["id"] == rec_out_of_id
		assert data["recipeClauseOf"]["id"] == rec_clause_of_id
	end

	test "deleteRecipeFlow()", %{recipe_flow: %{id: id}} do
		assert %{data: %{"deleteRecipeFlow" => true}} =
			mutation!("""
				deleteRecipeFlow(id: "#{id}")
			""")
	end
end
end
