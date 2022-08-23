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

defmodule ZenflowsTest.VF.RecipeExchange.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.uniq("name"),
			"note" => Factory.uniq("note"),
		},
		inserted: Factory.insert!(:recipe_exchange),
	}
end

@frag """
fragment recipeExchange on RecipeExchange {
	id
	name
	note
}
"""

describe "Query" do
	test "recipeExchange", %{inserted: new} do
		assert %{data: %{"recipeExchange" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					recipeExchange(id: $id) {...recipeExchange}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
	end
end

describe "Mutation" do
	test "createRecipeExchange", %{params: params} do
		assert %{data: %{"createRecipeExchange" => %{"recipeExchange" => data}}} =
			run!("""
				#{@frag}
				mutation ($recipeExchange: RecipeExchangeCreateParams!) {
					createRecipeExchange(recipeExchange: $recipeExchange) {
						recipeExchange {...recipeExchange}
					}
				}
			""", vars: %{"recipeExchange" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
	end

	test "updateRecipeExchange", %{params: params, inserted: old} do
		assert %{data: %{"updateRecipeExchange" => %{"recipeExchange" => data}}} =
			run!("""
				#{@frag}
				mutation ($recipeExchange: RecipeExchangeUpdateParams!) {
					updateRecipeExchange(recipeExchange: $recipeExchange) {
						recipeExchange {...recipeExchange}
					}
				}
			""", vars: %{"recipeExchange" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
	end

	test "deleteRecipeExchange", %{inserted: %{id: id}} do
		assert %{data: %{"deleteRecipeExchange" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteRecipeExchange(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
