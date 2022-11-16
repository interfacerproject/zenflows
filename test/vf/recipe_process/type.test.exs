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

defmodule ZenflowsTest.VF.RecipeProcess.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"hasDuration" => %{
				"unitType" => Factory.build(:time_unit) |> to_string(),
				"numericDuration" => Factory.decimal(),
			},
			"processClassifiedAs" => Factory.str_list("uri"),
			"processConformsTo" => Factory.insert!(:process_specification).id,
			"note" => Factory.str("note"),
		},
		inserted: Factory.insert!(:recipe_process),
	}
end

@frag """
fragment recipeProcess on RecipeProcess {
	id
	name
	note
	processClassifiedAs
	processConformsTo {id}
	hasDuration {
		unitType
		numericDuration
	}
}
"""

describe "Query" do
	test "recipeProcess", %{inserted: new} do
		assert %{data: %{"recipeProcess" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					recipeProcess(id: $id) {...recipeProcess}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
		assert data["processClassifiedAs"] == new.process_classified_as
		assert data["processConformsTo"]["id"] == new.process_conforms_to_id
		assert data["hasDuration"]["unitType"] == to_string(new.has_duration_unit_type)
		assert data["hasDuration"]["numericDuration"] == to_string(new.has_duration_numeric_duration)
	end
end

describe "Mutation" do
	test "createRecipeProcess", %{params: params} do
		assert %{data: %{"createRecipeProcess" => %{"recipeProcess" => data}}} =
			run!("""
				#{@frag}
				mutation ($recipeProcess: RecipeProcessCreateParams!) {
					createRecipeProcess(recipeProcess: $recipeProcess) {
						recipeProcess {...recipeProcess}
					}
				}
			""", vars: %{"recipeProcess" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
		assert data["processClassifiedAs"] == params["processClassifiedAs"]
		assert data["processConformsTo"]["id"] == params["processConformsTo"]
		assert data["hasDuration"] == params["hasDuration"]
	end

	test "updateRecipeProcess", %{params: params, inserted: old} do
		assert %{data: %{"updateRecipeProcess" => %{"recipeProcess" => data}}} =
			run!("""
				#{@frag}
				mutation ($recipeProcess: RecipeProcessUpdateParams!) {
					updateRecipeProcess(recipeProcess: $recipeProcess) {
						recipeProcess {...recipeProcess}
					}
				}
			""", vars: %{"recipeProcess" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
		assert data["processClassifiedAs"] == params["processClassifiedAs"]
		assert data["processConformsTo"]["id"] == params["processConformsTo"]
		assert data["hasDuration"] == params["hasDuration"]
	end

	test "updateRecipeProcess: hasDuration set null", %{params: params, inserted: old} do
		assert %{data: %{"updateRecipeProcess" => %{"recipeProcess" => data}}} =
			run!("""
				#{@frag}
				mutation ($recipeProcess: RecipeProcessUpdateParams!) {
					updateRecipeProcess(recipeProcess: $recipeProcess) {
						recipeProcess {...recipeProcess}
					}
				}
			""", vars: %{
				"recipeProcess" =>
					params
					|> Map.put("id", old.id)
					|> Map.put("hasDuration", nil)
			})

		assert data["id"] == old.id
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
		assert data["processClassifiedAs"] == params["processClassifiedAs"]
		assert data["processConformsTo"]["id"] == params["processConformsTo"]
		assert data["hasDuration"] == nil
	end

	test "deleteRecipeProcess", %{inserted: %{id: id}} do
		assert %{data: %{"deleteRecipeProcess" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteRecipeProcess(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
