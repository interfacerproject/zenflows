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
			name: Factory.uniq("name"),
			resource_classified_as: Factory.uniq_list("uri"),
			unit_of_effort_id: Factory.insert!(:unit).id,
			unit_of_resource_id: Factory.insert!(:unit).id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			substitutable: Factory.bool(),
			note: Factory.uniq("note"),
		},
		recipe_resource: Factory.insert!(:recipe_resource),
	}
end

describe "Query" do
	test "recipeResource()", %{recipe_resource: rec_res} do
		assert %{data: %{"recipeResource" => data}} =
			query!("""
				recipeResource(id: "#{rec_res.id}") {
					id
					name
					resourceClassifiedAs
					unitOfResource { id }
					unitOfEffort { id }
					resourceConformsTo { id }
					substitutable
					note
				}
			""")

		assert data["id"] == rec_res.id
		assert data["name"] == rec_res.name
		assert data["resourceClassifiedAs"] == rec_res.resource_classified_as
		assert data["unitOfResource"]["id"] == rec_res.unit_of_resource_id
		assert data["unitOfEffort"]["id"] == rec_res.unit_of_effort_id
		assert data["resourceConformsTo"]["id"] == rec_res.resource_conforms_to_id
		assert data["note"] == rec_res.note
	end
end

describe "Mutation" do
	test "createRecipeResource()", %{params: params} do
		assert %{data: %{"createRecipeResource" => %{"recipeResource" => data}}} =
			mutation!("""
				createRecipeResource(recipeResource: {
					name: "#{params.name}"
					resourceClassifiedAs: #{inspect(params.resource_classified_as)}
					unitOfResource: "#{params.unit_of_resource_id}"
					unitOfEffort: "#{params.unit_of_effort_id}"
					resourceConformsTo: "#{params.resource_conforms_to_id}"
					substitutable: #{params.substitutable}
					note: "#{params.note}"
				}) {
					recipeResource {
						id
						name
						resourceClassifiedAs
						unitOfResource { id }
						unitOfEffort { id }
						resourceConformsTo { id }
						substitutable
						note
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["resourceClassifiedAs"] == params.resource_classified_as
		assert data["unitOfResource"]["id"] == params.unit_of_resource_id
		assert data["unitOfEffort"]["id"] == params.unit_of_effort_id
		assert data["resourceConformsTo"]["id"] == params.resource_conforms_to_id
		assert data["note"] == params.note
	end

	test "updateRecipeResource()", %{params: params, recipe_resource: rec_res} do
		assert %{data: %{"updateRecipeResource" => %{"recipeResource" => data}}} =
			mutation!("""
				updateRecipeResource(recipeResource: {
					id: "#{rec_res.id}"
					name: "#{params.name}"
					resourceClassifiedAs: #{inspect(params.resource_classified_as)}
					unitOfResource: "#{params.unit_of_resource_id}"
					unitOfEffort: "#{params.unit_of_effort_id}"
					resourceConformsTo: "#{params.resource_conforms_to_id}"
					substitutable: #{params.substitutable}
					note: "#{params.note}"
				}) {
					recipeResource {
						id
						name
						resourceClassifiedAs
						unitOfResource { id }
						unitOfEffort { id }
						resourceConformsTo { id }
						substitutable
						note
					}
				}
			""")

		assert data["id"] == rec_res.id
		assert data["name"] == params.name
		assert data["resourceClassifiedAs"] == params.resource_classified_as
		assert data["unitOfResource"]["id"] == params.unit_of_resource_id
		assert data["unitOfEffort"]["id"] == params.unit_of_effort_id
		assert data["resourceConformsTo"]["id"] == params.resource_conforms_to_id
		assert data["note"] == params.note
	end

	test "deleteRecipeResource()", %{recipe_resource: %{id: id}} do
		assert %{data: %{"deleteRecipeResource" => true}} =
			mutation!("""
				deleteRecipeResource(id: "#{id}")
			""")
	end
end
end
