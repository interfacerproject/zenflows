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
			name: Factory.uniq("name"),
			has_duration: Factory.build(:iduration),
			process_classified_as: Factory.uniq_list("uri"),
			process_conforms_to_id: Factory.insert!(:process_specification).id,
			note: Factory.uniq("note"),
		},
		inserted: Factory.insert!(:recipe_process),
	}
end

describe "Query" do
	test "recipeProcess()", %{inserted: rec_proc} do
		assert %{data: %{"recipeProcess" => data}} =
			query!("""
				recipeProcess(id: "#{rec_proc.id}") {
					id
					name
					note
					processClassifiedAs
					processConformsTo { id }
					hasDuration {
						unitType
						numericDuration
					}
				}
			""")

		assert data["id"] == rec_proc.id
		assert data["name"] == rec_proc.name
		assert data["note"] == rec_proc.note
		assert data["processClassifiedAs"] == rec_proc.process_classified_as
		assert data["processConformsTo"]["id"] == rec_proc.process_conforms_to_id
		assert data["hasDuration"]["unitType"] == to_string(rec_proc.has_duration_unit_type)
		assert data["hasDuration"]["numericDuration"] == rec_proc.has_duration_numeric_duration
	end
end

describe "Mutation" do
	test "createRecipeProcess()", %{params: params} do
		assert %{data: %{"createRecipeProcess" => %{"recipeProcess" => data}}} =
			mutation!("""
				createRecipeProcess(recipeProcess: {
					name: "#{params.name}"
					note: "#{params.note}"
					processClassifiedAs: #{inspect(params.process_classified_as)}
					processConformsTo: "#{params.process_conforms_to_id}"
					hasDuration: {
						unitType: #{params.has_duration.unit_type}
						numericDuration: #{params.has_duration.numeric_duration}
					}
				}) {
					recipeProcess {
						id
						name
						note
						processClassifiedAs
						processConformsTo { id }
						hasDuration {
							unitType
							numericDuration
						}
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["processClassifiedAs"] == params.process_classified_as
		assert data["processConformsTo"]["id"] == params.process_conforms_to_id
		assert data["hasDuration"]["unitType"] == to_string(params.has_duration.unit_type)
		assert data["hasDuration"]["numericDuration"] == params.has_duration.numeric_duration
	end

	test "updateRecipeProcess()", %{params: params, inserted: rec_proc} do
		assert %{data: %{"updateRecipeProcess" => %{"recipeProcess" => data}}} =
			mutation!("""
				updateRecipeProcess(recipeProcess: {
					id: "#{rec_proc.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					processClassifiedAs: #{inspect(params.process_classified_as)}
					processConformsTo: "#{params.process_conforms_to_id}"
					hasDuration: {
						unitType: #{params.has_duration.unit_type}
						numericDuration: #{params.has_duration.numeric_duration}
					}
				}) {
					recipeProcess {
						id
						name
						note
						processClassifiedAs
						processConformsTo { id }
						hasDuration {
							unitType
							numericDuration
						}
					}
				}
			""")

		assert data["id"] == rec_proc.id
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["processClassifiedAs"] == params.process_classified_as
		assert data["processConformsTo"]["id"] == params.process_conforms_to_id
		assert data["hasDuration"]["unitType"] == to_string(params.has_duration.unit_type)
		assert data["hasDuration"]["numericDuration"] == params.has_duration.numeric_duration
	end

	test "updateRecipeProcess(), set hasDuration to null", %{params: params, inserted: rec_proc} do
		assert %{data: %{"updateRecipeProcess" => %{"recipeProcess" => data}}} =
			mutation!("""
				updateRecipeProcess(recipeProcess: {
					id: "#{rec_proc.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					processClassifiedAs: #{inspect(params.process_classified_as)}
					processConformsTo: "#{params.process_conforms_to_id}"
					hasDuration: null
				}) {
					recipeProcess {
						id
						name
						note
						processClassifiedAs
						processConformsTo { id }
						hasDuration {
							unitType
							numericDuration
						}
					}
				}
			""")

		assert data["id"] == rec_proc.id
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["processClassifiedAs"] == params.process_classified_as
		assert data["processConformsTo"]["id"] == params.process_conforms_to_id
		assert data["hasDuration"]["unitType"] == nil
		assert data["hasDuration"]["numericDuration"] == nil
	end

	test "deleteRecipeProcess()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteRecipeProcess" => true}} =
			mutation!("""
				deleteRecipeProcess(id: "#{id}")
			""")
	end
end
end
