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

defmodule ZenflowsTest.VF.Plan.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			created: DateTime.utc_now(),
			due: DateTime.utc_now(),
			refinement_of_id: Factory.insert!(:scenario).id,
		},
		inserted: Factory.insert!(:plan),
	}
end

describe "Query" do
	test "plan()", %{inserted: plan} do
		assert %{data: %{"plan" => data}} =
			query!("""
				plan(id: "#{plan.id}") {
					id
					name
					note
					created
					due
					refinementOf {id}
				}
			""")

		assert data["id"] == plan.id
		assert data["name"] == plan.name
		assert data["note"] == plan.note
		assert data["created"] == DateTime.to_iso8601(plan.created)
		assert data["due"] == DateTime.to_iso8601(plan.due)
		assert data["refinementOf"]["id"] == plan.refinement_of_id
	end
end

describe "Mutation" do
	test "createPlan()", %{params: params} do
		assert %{data: %{"createPlan" => %{"plan" => data}}} =
			mutation!("""
				createPlan(plan: {
					name: "#{params.name}"
					note: "#{params.note}"
					created: "#{params.created}"
					due: "#{params.due}"
					refinementOf: "#{params.refinement_of_id}"
				}) {
					plan {
						id
						name
						note
						created
						due
						refinementOf {id}
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["created"] == DateTime.to_iso8601(params.created)
		assert data["due"] == DateTime.to_iso8601(params.due)
		assert data["refinementOf"]["id"] == params.refinement_of_id
	end

	test "updatePlan()", %{params: params, inserted: plan} do
		assert %{data: %{"updatePlan" => %{"plan" => data}}} =
			mutation!("""
				updatePlan(plan: {
					id: "#{plan.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					created: "#{params.created}"
					due: "#{params.due}"
					refinementOf: "#{params.refinement_of_id}"
				}) {
					plan {
						id
						name
						note
						created
						due
						refinementOf {id}
					}
				}
			""")

		assert data["id"] == plan.id
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["created"] == DateTime.to_iso8601(params.created)
		assert data["due"] == DateTime.to_iso8601(params.due)
		assert data["refinementOf"]["id"] == params.refinement_of_id
	end

	test "deletePlan()", %{inserted: %{id: id}} do
		assert %{data: %{"deletePlan" => true}} =
			mutation!("""
				deletePlan(id: "#{id}")
			""")
	end
end
end
