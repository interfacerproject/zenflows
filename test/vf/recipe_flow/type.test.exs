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

defmodule ZenflowsTest.VF.RecipeFlow.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"note" => Factory.uniq("some note"),
			"action" => Factory.build(:action_id),
			"recipeInputOf" => Factory.insert!(:recipe_process).id,
			"recipeOutputOf" => Factory.insert!(:recipe_process).id,
			"recipeFlowResource" => Factory.insert!(:recipe_resource).id,
			"resourceQuantity" => %{
				"hasUnit" => Factory.insert!(:unit).id,
				"hasNumericalValue" => Factory.float(),
			},
			"effortQuantity" => %{
				"hasUnit" => Factory.insert!(:unit).id,
				"hasNumericalValue" => Factory.float(),
			},
			"recipeClauseOf" => Factory.insert!(:recipe_exchange).id,
		},
		inserted: Factory.insert!(:recipe_flow),
	}
end

@frag """
fragment recipeFlow on RecipeFlow {
	id
	note
	action {id}
	resourceQuantity {
		hasUnit {id}
		hasNumericalValue
	}
	effortQuantity {
		hasUnit {id}
		hasNumericalValue
	}
	recipeFlowResource {id}
	recipeInputOf {id}
	recipeOutputOf {id}
	recipeClauseOf {id}
}
"""

describe "Query" do
	test "recipeFlow", %{inserted: new} do
		assert %{data: %{"recipeFlow" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					recipeFlow(id: $id) {...recipeFlow}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["note"] == new.note
		assert data["action"]["id"] == new.action_id
		assert data["resourceQuantity"]["hasUnit"]["id"] == new.resource_quantity_has_unit_id
		assert data["resourceQuantity"]["hasNumericalValue"] == new.resource_quantity_has_numerical_value
		assert data["effortQuantity"]["hasUnit"]["id"] == new.effort_quantity_has_unit_id
		assert data["effortQuantity"]["hasNumericalValue"] == new.effort_quantity_has_numerical_value
		assert data["recipeFlowResource"]["id"] == new.recipe_flow_resource_id
		assert data["recipeInputOf"]["id"] == new.recipe_input_of_id
		assert data["recipeOutputOf"]["id"] == new.recipe_output_of_id
		assert data["recipeClauseOf"]["id"] == new.recipe_clause_of_id
	end
end

describe "Mutation" do
	test "createRecipeFlow", %{params: params} do
		assert %{data: %{"createRecipeFlow" => %{"recipeFlow" => data}}} =
			run!("""
				#{@frag}
				mutation ($recipeFlow: RecipeFlowCreateParams!) {
					createRecipeFlow(recipeFlow: $recipeFlow) {
						recipeFlow {...recipeFlow}
					}
				}
			""", vars: %{"recipeFlow" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["note"] == params["note"]
		assert data["action"]["id"] == params["action"]
		assert data["resourceQuantity"]["hasUnit"]["id"] == params["resourceQuantity"]["hasUnit"]
		assert data["resourceQuantity"]["hasNumericalValue"] == params["resourceQuantity"]["hasNumericalValue"]
		assert data["effortQuantity"]["hasUnit"]["id"] == params["effortQuantity"]["hasUnit"]
		assert data["effortQuantity"]["hasNumericalValue"] == params["effortQuantity"]["hasNumericalValue"]
		assert data["recipeFlowResource"]["id"] == params["recipeFlowResource"]
		assert data["recipeInputOf"]["id"] == params["recipeInputOf"]
		assert data["recipeOutputOf"]["id"] == params["recipeOutputOf"]
		assert data["recipeClauseOf"]["id"] == params["recipeClauseOf"]
	end

	test "updateRecipeFlow", %{params: params, inserted: old} do
		assert %{data: %{"updateRecipeFlow" => %{"recipeFlow" => data}}} =
			run!("""
				#{@frag}
				mutation ($recipeFlow: RecipeFlowUpdateParams!) {
					updateRecipeFlow(recipeFlow: $recipeFlow) {
						recipeFlow {...recipeFlow}
					}
				}
			""", vars: %{"recipeFlow" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		assert data["note"] == params["note"]
		assert data["action"]["id"] == params["action"]
		assert data["resourceQuantity"]["hasUnit"]["id"] == params["resourceQuantity"]["hasUnit"]
		assert data["resourceQuantity"]["hasNumericalValue"] == params["resourceQuantity"]["hasNumericalValue"]
		assert data["effortQuantity"]["hasUnit"]["id"] == params["effortQuantity"]["hasUnit"]
		assert data["effortQuantity"]["hasNumericalValue"] == params["effortQuantity"]["hasNumericalValue"]
		assert data["recipeFlowResource"]["id"] == params["recipeFlowResource"]
		assert data["recipeInputOf"]["id"] == params["recipeInputOf"]
		assert data["recipeOutputOf"]["id"] == params["recipeOutputOf"]
		assert data["recipeClauseOf"]["id"] == params["recipeClauseOf"]
	end

	test "deleteRecipeFlow", %{inserted: %{id: id}} do
		assert %{data: %{"deleteRecipeFlow" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteRecipeFlow(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
