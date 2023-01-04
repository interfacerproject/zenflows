# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

defmodule ZenflowsTest.VF.Plan.Type do
@moduledoc "A man, a plan, a canal: panama."

use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
			"due" => Factory.iso_now(),
			"refinementOf" => Factory.insert!(:scenario).id,
		},
		inserted: Factory.insert!(:plan),
	}
end

@frag """
fragment plan on Plan {
	id
	name
	note
	created
	due
	refinementOf {id}
}
"""

describe "Query" do
	test "plan", %{inserted: plan} do
		assert %{data: %{"plan" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					plan(id: $id) {...plan}
				}
			""", vars: %{"id" => plan.id})

		assert data["id"] == plan.id
		assert data["name"] == plan.name
		assert data["note"] == plan.note
		assert data["due"] == DateTime.to_iso8601(plan.due)
		assert data["refinementOf"]["id"] == plan.refinement_of_id
		assert {:ok, created, 0} = DateTime.from_iso8601(data["created"])
		assert DateTime.compare(DateTime.utc_now(), created) != :lt
	end
end

describe "Mutation" do
	test "createPlan", %{params: params} do
		assert %{data: %{"createPlan" => %{"plan" => data}}} =
			run!("""
				#{@frag}
				mutation ($plan: PlanCreateParams!) {
					createPlan(plan: $plan) {
						plan {...plan}
					}
				}
			""", vars: %{"plan" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
		assert data["due"] == params["due"]
		assert data["refinementOf"]["id"] == params["refinementOf"]
		assert {:ok, created, 0} = DateTime.from_iso8601(data["created"])
		assert DateTime.compare(DateTime.utc_now(), created) != :lt
	end

	test "updatePlan", %{params: params, inserted: plan} do
		assert %{data: %{"updatePlan" => %{"plan" => data}}} =
			run!("""
				#{@frag}
				mutation ($plan: PlanUpdateParams!) {
					updatePlan(plan: $plan) {
						plan {...plan}
					}
				}
			""", vars: %{"plan" => params |> Map.put("id", plan.id)})

		assert data["id"] == plan.id
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
		assert data["due"] == params["due"]
		assert data["refinementOf"]["id"] == params["refinementOf"]
		assert {:ok, created, 0} = DateTime.from_iso8601(data["created"])
		assert DateTime.compare(DateTime.utc_now(), created) != :lt
	end

	test "deletePlan", %{inserted: %{id: id}} do
		assert %{data: %{"deletePlan" => true}} =
			run!("""
				mutation ($id: ID!) {
					deletePlan(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
