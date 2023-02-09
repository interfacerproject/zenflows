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

defmodule ZenflowsTest.VF.RecipeResource.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"resourceClassifiedAs" => Factory.str_list("uri"),
			"unitOfEffort" => Factory.insert!(:unit).id,
			"unitOfResource" => Factory.insert!(:unit).id,
			"resourceConformsTo" => Factory.insert!(:resource_specification).id,
			"substitutable" => Factory.bool(),
			"note" => Factory.str("note"),
		},
		inserted: Factory.insert!(:recipe_resource),
	}
end

@frag """
fragment recipeResource on RecipeResource {
	id
	name
	resourceClassifiedAs
	unitOfResource {id}
	unitOfEffort {id}
	resourceConformsTo {id}
	substitutable
	note
}
"""

describe "Query" do
	test "recipeResource", %{inserted: new} do
		assert %{data: %{"recipeResource" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					recipeResource(id: $id) {...recipeResource}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["resourceClassifiedAs"] == new.resource_classified_as
		assert data["unitOfResource"]["id"] == new.unit_of_resource_id
		assert data["unitOfEffort"]["id"] == new.unit_of_effort_id
		assert data["resourceConformsTo"]["id"] == new.resource_conforms_to_id
		assert data["note"] == new.note
		assert data["substitutable"] == new.substitutable
	end
end

describe "Mutation" do
	test "createRecipeResource", %{params: params} do
		assert %{data: %{"createRecipeResource" => %{"recipeResource" => data}}} =
			run!("""
				#{@frag}
				mutation ($recipeResource: RecipeResourceCreateParams!) {
					createRecipeResource(recipeResource: $recipeResource) {
						recipeResource {...recipeResource}
					}
				}
			""", vars: %{"recipeResource" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		keys = ~w[name note resourceClassifiedAs substitutable]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["unitOfResource"]["id"] == params["unitOfResource"]
		assert data["unitOfEffort"]["id"] == params["unitOfEffort"]
		assert data["resourceConformsTo"]["id"] == params["resourceConformsTo"]
	end

	test "updateRecipeResource()", %{params: params, inserted: old} do
		assert %{data: %{"updateRecipeResource" => %{"recipeResource" => data}}} =
			run!("""
				#{@frag}
				mutation ($recipeResource: RecipeResourceUpdateParams!) {
					updateRecipeResource(recipeResource: $recipeResource) {
						recipeResource {...recipeResource}
					}
				}
			""", vars: %{"recipeResource" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		keys = ~w[name note resourceClassifiedAs substitutable]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["unitOfResource"]["id"] == params["unitOfResource"]
		assert data["unitOfEffort"]["id"] == params["unitOfEffort"]
		assert data["resourceConformsTo"]["id"] == params["resourceConformsTo"]
	end

	test "deleteRecipeResource()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteRecipeResource" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteRecipeResource(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
