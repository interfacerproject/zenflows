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

defmodule ZenflowsTest.VF.ScenarioDefinition.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
			"hasDuration" => %{
				"unitType" => Factory.build(:time_unit) |> to_string(),
				"numericDuration" => Factory.decimal(),
			},
		},
		inserted: Factory.insert!(:scenario_definition),
	}
end

@frag """
fragment scenarioDefinition on ScenarioDefinition {
	id
	name
	note
	hasDuration {
		unitType
		numericDuration
	}
}
"""

describe "Query" do
	test "scenarioDefinition", %{inserted: new} do
		assert %{data: %{"scenarioDefinition" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					scenarioDefinition(id: $id) {...scenarioDefinition}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
		assert data["hasDuration"]["unitType"] == to_string(new.has_duration_unit_type)
		assert Decimal.eq?(data["hasDuration"]["numericDuration"], new.has_duration_numeric_duration)
	end
end

describe "Mutation" do
	test "createScenarioDefinition", %{params: params} do
		assert %{data: %{"createScenarioDefinition" => %{"scenarioDefinition" => data}}} =
			run!("""
				#{@frag}
				mutation ($scenarioDefinition: ScenarioDefinitionCreateParams!) {
					createScenarioDefinition(scenarioDefinition: $scenarioDefinition) {
						scenarioDefinition {...scenarioDefinition}
					}
				}
			""", vars: %{"scenarioDefinition" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
		assert data["hasDuration"] == params["hasDuration"]
	end

	test "updateScenarioDefinition", %{params: params, inserted: old} do
		assert %{data: %{"updateScenarioDefinition" => %{"scenarioDefinition" => data}}} =
			run!("""
				#{@frag}
				mutation ($scenarioDefinition: ScenarioDefinitionUpdateParams!) {
					updateScenarioDefinition(scenarioDefinition: $scenarioDefinition) {
						scenarioDefinition {...scenarioDefinition}
					}
				}
			""", vars: %{"scenarioDefinition" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
		assert data["hasDuration"] == params["hasDuration"]
	end

	test "deleteScenarioDefinition()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteScenarioDefinition" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteScenarioDefinition(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
