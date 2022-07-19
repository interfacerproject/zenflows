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

defmodule ZenflowsTest.VF.Scenario.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
			defined_as_id: Factory.insert!(:scenario_definition).id,
			refinement_of_id: Factory.insert!(:scenario).id,
		},
		inserted: Factory.insert!(:scenario),
	}
end

describe "Query" do
	test "scenario()", %{inserted: scen} do
		assert %{data: %{"scenario" => data}} =
			query!("""
				scenario(id: "#{scen.id}") {
					id
					name
					note
					hasBeginning
					hasEnd
					definedAs {id}
					refinementOf {id}
				}
			""")

		assert data["id"] == scen.id
		assert data["name"] == scen.name
		assert data["note"] == scen.note
		assert data["hasBeginning"] == DateTime.to_iso8601(scen.has_beginning)
		assert data["hasEnd"] == DateTime.to_iso8601(scen.has_end)
		assert data["definedAs"]["id"] == scen.defined_as_id
		assert data["refinementOf"]["id"] == scen.refinement_of_id
	end
end

describe "Mutation" do
	test "createScenario()", %{params: params} do
		assert %{data: %{"createScenario" => %{"scenario" => data}}} =
			mutation!("""
				createScenario(scenario: {
					name: "#{params.name}"
					note: "#{params.note}"
					hasBeginning: "#{params.has_beginning}"
					hasEnd: "#{params.has_end}"
					definedAs: "#{params.defined_as_id}"
					refinementOf: "#{params.refinement_of_id}"
				}) {
					scenario {
						id
						name
						note
						hasBeginning
						hasEnd
						definedAs {id}
						refinementOf {id}
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["hasBeginning"] == DateTime.to_iso8601(params.has_beginning)
		assert data["hasEnd"] == DateTime.to_iso8601(params.has_end)
		assert data["definedAs"]["id"] == params.defined_as_id
		assert data["refinementOf"]["id"] == params.refinement_of_id
	end

	test "updateScenario()", %{params: params, inserted: scen} do
		assert %{data: %{"updateScenario" => %{"scenario" => data}}} =
			mutation!("""
				updateScenario(scenario: {
					id: "#{scen.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					hasBeginning: "#{params.has_beginning}"
					hasEnd: "#{params.has_end}"
					definedAs: "#{params.defined_as_id}"
					refinementOf: "#{params.refinement_of_id}"
				}) {
					scenario {
						id
						name
						note
						hasBeginning
						hasEnd
						definedAs {id}
						refinementOf {id}
					}
				}
			""")

		assert data["id"] == scen.id
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["hasBeginning"] == DateTime.to_iso8601(params.has_beginning)
		assert data["hasEnd"] == DateTime.to_iso8601(params.has_end)
		assert data["definedAs"]["id"] == params.defined_as_id
		assert data["refinementOf"]["id"] == params.refinement_of_id
	end

	test "deleteScenario()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteScenario" => true}} =
			mutation!("""
				deleteScenario(id: "#{id}")
			""")
	end
end
end
