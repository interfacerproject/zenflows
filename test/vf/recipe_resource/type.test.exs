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

defmodule ZenflowsTest.VF.RecipeResource.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.uniq("name"),
			"resourceClassifiedAs" => Factory.uniq_list("uri"),
			"unitOfEffort" => Factory.insert!(:unit).id,
			"unitOfResource" => Factory.insert!(:unit).id,
			"resourceConformsTo" => Factory.insert!(:resource_specification).id,
			"substitutable" => Factory.bool(),
			"note" => Factory.uniq("note"),
			"image" => Factory.img(),
		},
		recipe_resource: Factory.insert!(:recipe_resource),
	}
end

describe "Query" do
	test "recipeResource()", %{recipe_resource: rec_res} do
		assert %{data: %{"recipeResource" => data}} =
			run!("""
				query ($id: ID!) {
					recipeResource(id: $id) {
						id
						name
						resourceClassifiedAs
						unitOfResource { id }
						unitOfEffort { id }
						resourceConformsTo { id }
						substitutable
						image
						note
					}
				}
			""", vars: %{"id" => rec_res.id})

		assert data["id"] == rec_res.id
		assert data["name"] == rec_res.name
		assert data["resourceClassifiedAs"] == rec_res.resource_classified_as
		assert data["unitOfResource"]["id"] == rec_res.unit_of_resource_id
		assert data["unitOfEffort"]["id"] == rec_res.unit_of_effort_id
		assert data["resourceConformsTo"]["id"] == rec_res.resource_conforms_to_id
		assert data["note"] == rec_res.note
		assert data["substitutable"] == rec_res.substitutable
		assert data["image"] == rec_res.image
	end
end

describe "Mutation" do
	test "createRecipeResource()", %{params: params} do
		assert %{data: %{"createRecipeResource" => %{"recipeResource" => data}}} =
			run!("""
				mutation ($recipeResource: RecipeResourceCreateParams!) {
					createRecipeResource(recipeResource: $recipeResource) {
						recipeResource {
							id
							name
							image
							resourceClassifiedAs
							unitOfResource { id }
							unitOfEffort { id }
							resourceConformsTo { id }
							substitutable
							note
						}
					}
				}
			""", vars: %{"recipeResource" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		keys = ~w[name note image resourceClassifiedAs substitutable]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["unitOfResource"]["id"] == params["unitOfResource"]
		assert data["unitOfEffort"]["id"] == params["unitOfEffort"]
		assert data["resourceConformsTo"]["id"] == params["resourceConformsTo"]
	end

	test "updateRecipeResource()", %{params: params, recipe_resource: rec_res} do
		assert %{data: %{"updateRecipeResource" => %{"recipeResource" => data}}} =
			run!("""
				mutation ($recipeResource: RecipeResourceUpdateParams!) {
					updateRecipeResource(recipeResource: $recipeResource) {
						recipeResource {
							id
							name
							resourceClassifiedAs
							unitOfResource { id }
							unitOfEffort { id }
							resourceConformsTo { id }
							substitutable
							note
							image
						}
					}
				}
			""", vars: %{"recipeResource" => Map.put(params, "id", rec_res.id)})

		assert data["id"] == rec_res.id
		keys = ~w[name note image resourceClassifiedAs substitutable]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["unitOfResource"]["id"] == params["unitOfResource"]
		assert data["unitOfEffort"]["id"] == params["unitOfEffort"]
		assert data["resourceConformsTo"]["id"] == params["resourceConformsTo"]
	end

	test "deleteRecipeResource()", %{recipe_resource: %{id: id}} do
		assert %{data: %{"deleteRecipeResource" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteRecipeResource(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
