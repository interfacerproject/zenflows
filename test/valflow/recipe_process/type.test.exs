defmodule ZenflowsTest.Valflow.RecipeProcess.Type do
use ZenflowsTest.Case.Absin, async: true

alias Zenflows.Valflow.RecipeProcess.Domain

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			has_duration: Factory.build_map!(:duration),
			process_classified_as: Factory.uniq_list("uri"),
			process_conforms_to_id: Factory.insert!(:process_specification).id,
			note: Factory.uniq("note"),
		},
		recipe_process: Factory.insert!(:recipe_process) |> Domain.preload(:has_duration),
	}
end

describe "Query" do
	test "recipeProcess()", %{recipe_process: %{has_duration: dur} = rec_proc} do
		assert %{data: %{"recipeProcess" => data}} =
			query!("""
				recipeProcess(id: "#{rec_proc.id}") {
					id
					name
					note
					processClassifiedAs
					hasDuration {
						unitType
						numericDuration
					}
					processConformsTo { id }
				}
			""")

		assert data["id"] == rec_proc.id
		assert data["name"] == rec_proc.name
		assert data["note"] == rec_proc.note
		assert data["processClassifiedAs"] == rec_proc.process_classified_as
		assert data["hasDuration"]["unitType"] == to_string(dur.unit_type)
		assert data["hasDuration"]["numericDuration"] == dur.numeric_duration
		assert data["processConformsTo"]["id"] == rec_proc.process_conforms_to_id
	end
end

describe "Mutation" do
	test "createRecipeProcess()", %{params: %{has_duration: dur} = params} do
		assert %{data: %{"createRecipeProcess" => %{"recipeProcess" => data}}} =
			mutation!("""
				createRecipeProcess(recipeProcess: {
					name: "#{params.name}"
					note: "#{params.note}"
					processConformsTo: "#{params.process_conforms_to_id}"
					processClassifiedAs: #{inspect(params.process_classified_as)}
					hasDuration: {
						unitType: #{to_string(dur.unit_type)}
						numericDuration: #{dur.numeric_duration}
					}
				}) {
					recipeProcess {
						id
						name
						note
						processClassifiedAs
						hasDuration {
							unitType
							numericDuration
						}
						processConformsTo { id }
					}
				}
			""")

		assert {:ok, _} = Zenflows.Ecto.Id.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["processClassifiedAs"] == params.process_classified_as
		assert data["processConformsTo"]["id"] == params.process_conforms_to_id
		assert data["hasDuration"]["unitType"] == to_string(dur.unit_type)
		assert data["hasDuration"]["numericDuration"] == dur.numeric_duration
	end

	test "updateRecipeProcess()", %{params: params, recipe_process: %{has_duration: dur} = rec_proc} do
		assert %{data: %{"updateRecipeProcess" => %{"recipeProcess" => data}}} =
			mutation!("""
				updateRecipeProcess(recipeProcess: {
					id: "#{rec_proc.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					processConformsTo: "#{params.process_conforms_to_id}"
					processClassifiedAs: #{inspect(params.process_classified_as)}
					hasDuration: {
						unitType: #{to_string(dur.unit_type)}
						numericDuration: #{dur.numeric_duration}
					}
				}) {
					recipeProcess {
						id
						name
						note
						processClassifiedAs
						hasDuration {
							unitType
							numericDuration
						}
						processConformsTo { id }
					}
				}
			""")

		assert data["id"] == rec_proc.id
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["processClassifiedAs"] == params.process_classified_as
		assert data["processConformsTo"]["id"] == params.process_conforms_to_id
		assert data["hasDuration"]["unitType"] == to_string(dur.unit_type)
		assert data["hasDuration"]["numericDuration"] == dur.numeric_duration
	end

	test "deleteRecipeProcess()", %{recipe_process: %{id: id}} do
		assert %{data: %{"deleteRecipeProcess" => true}} =
			mutation!("""
				deleteRecipeProcess(id: "#{id}")
			""")
	end
end
end
