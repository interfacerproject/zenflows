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

defmodule ZenflowsTest.VF.Scenario.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
			"hasBeginning" => Factory.iso_now(),
			"hasEnd" => Factory.iso_now(),
			"definedAs" => Factory.insert!(:scenario_definition).id,
			"refinementOf" => Factory.insert!(:scenario).id,
		},
		inserted: Factory.insert!(:scenario),
	}
end

@frag """
fragment scenario on Scenario {
	id
	name
	note
	hasBeginning
	hasEnd
	definedAs {id}
	refinementOf {id}
}
"""

describe "Query" do
	test "scenario", %{inserted: new} do
		assert %{data: %{"scenario" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					scenario(id: $id) {...scenario}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
		assert data["hasBeginning"] == DateTime.to_iso8601(new.has_beginning)
		assert data["hasEnd"] == DateTime.to_iso8601(new.has_end)
		assert data["definedAs"]["id"] == new.defined_as_id
		assert data["refinementOf"]["id"] == new.refinement_of_id
	end
end

describe "Mutation" do
	test "createScenario", %{params: params} do
		assert %{data: %{"createScenario" => %{"scenario" => data}}} =
			run!("""
				#{@frag}
				mutation ($scenario: ScenarioCreateParams!) {
					createScenario(scenario: $scenario) {
						scenario {...scenario}
					}
				}
			""", vars: %{"scenario" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		keys = ~w[name note hasBeginning hasEnd]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["definedAs"]["id"] == params["definedAs"]
		assert data["refinementOf"]["id"] == params["refinementOf"]
	end

	test "updateScenario", %{params: params, inserted: old} do
		assert %{data: %{"updateScenario" => %{"scenario" => data}}} =
			run!("""
				#{@frag}
				mutation ($scenario: ScenarioUpdateParams!) {
					updateScenario(scenario: $scenario) {
						scenario {...scenario}
					}
				}
			""", vars: %{"scenario" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		keys = ~w[name note hasBeginning hasEnd]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["definedAs"]["id"] == params["definedAs"]
		assert data["refinementOf"]["id"] == params["refinementOf"]
	end

	test "deleteScenario", %{inserted: %{id: id}} do
		assert %{data: %{"deleteScenario" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteScenario(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
