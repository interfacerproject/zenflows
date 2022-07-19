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

defmodule ZenflowsTest.VF.ScenarioDefinition.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			has_duration: Factory.build(:iduration),
		},
		inserted: Factory.insert!(:scenario_definition),
	}
end

describe "Query" do
	test "scenarioDefinition()", %{inserted: scen_def} do
		assert %{data: %{"scenarioDefinition" => data}} =
			query!("""
				scenarioDefinition(id: "#{scen_def.id}") {
					id
					name
					note
					hasDuration {
						unitType
						numericDuration
					}
				}
			""")

		assert data["id"] == scen_def.id
		assert data["name"] == scen_def.name
		assert data["note"] == scen_def.note
		assert data["hasDuration"]["unitType"] == to_string(scen_def.has_duration_unit_type)
		assert data["hasDuration"]["numericDuration"] == scen_def.has_duration_numeric_duration
	end
end

describe "Mutation" do
	test "createScenarioDefinition()", %{params: params} do
		assert %{data: %{"createScenarioDefinition" => %{"scenarioDefinition" => data}}} =
			mutation!("""
				createScenarioDefinition(scenarioDefinition: {
					name: "#{params.name}"
					note: "#{params.note}"
					hasDuration: {
						unitType: #{params.has_duration.unit_type}
						numericDuration: #{params.has_duration.numeric_duration}
					}
				}) {
					scenarioDefinition {
						id
						name
						note
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
		assert data["hasDuration"]["unitType"] == to_string(params.has_duration.unit_type)
		assert data["hasDuration"]["numericDuration"] == params.has_duration.numeric_duration
	end

	test "updateScenarioDefinition()", %{params: params, inserted: scen_def} do
		assert %{data: %{"updateScenarioDefinition" => %{"scenarioDefinition" => data}}} =
			mutation!("""
				updateScenarioDefinition(scenarioDefinition: {
					id: "#{scen_def.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					hasDuration: {
						unitType: #{params.has_duration.unit_type}
						numericDuration: #{params.has_duration.numeric_duration}
					}
				}) {
					scenarioDefinition {
						id
						name
						note
						hasDuration {
							unitType
							numericDuration
						}
					}
				}
			""")

		assert data["id"] == scen_def.id
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["hasDuration"]["unitType"] == to_string(params.has_duration.unit_type)
		assert data["hasDuration"]["numericDuration"] == params.has_duration.numeric_duration
	end

	test "deleteScenarioDefinition()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteScenarioDefinition" => true}} =
			mutation!("""
				deleteScenarioDefinition(id: "#{id}")
			""")
	end
end
end
