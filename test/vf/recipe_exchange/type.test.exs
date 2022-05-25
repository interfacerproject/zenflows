defmodule ZenflowsTest.VF.RecipeExchange.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		recipe_exchange: Factory.insert!(:recipe_exchange),
	}
end

describe "Query" do
	test "recipeExchange()", %{recipe_exchange: rec_exch} do
		assert %{data: %{"recipeExchange" => data}} =
			query!("""
				recipeExchange(id: "#{rec_exch.id}") {
					id
					name
					note
				}
			""")

		assert data["id"] == rec_exch.id
		assert data["name"] == rec_exch.name
		assert data["note"] == rec_exch.note
	end
end

describe "Mutation" do
	test "createRecipeExchange()", %{params: params} do
		assert %{data: %{"createRecipeExchange" => %{"recipeExchange" => data}}} =
			mutation!("""
				createRecipeExchange(recipeExchange: {
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					recipeExchange {
						id
						name
						note
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
	end

	test "updateRecipeExchange()", %{params: params, recipe_exchange: rec_exch} do
		assert %{data: %{"updateRecipeExchange" => %{"recipeExchange" => data}}} =
			mutation!("""
				updateRecipeExchange(recipeExchange: {
					id: "#{rec_exch.id}"
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					recipeExchange {
						id
						name
						note
					}
				}
			""")

		assert data["id"] == rec_exch.id
		assert data["name"] == params.name
		assert data["note"] == params.note
	end

	test "deleteRecipeExchange()", %{recipe_exchange: %{id: id}} do
		assert %{data: %{"deleteRecipeExchange" => true}} =
			mutation!("""
				deleteRecipeExchange(id: "#{id}")
			""")
	end
end
end
