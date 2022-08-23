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

defmodule ZenflowsTest.VF.ProcessSpecification.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
		},
		inserted: Factory.insert!(:process_specification),
	}
end

@frag """
fragment processSpecification on ProcessSpecification {
	id
	name
	note
}
"""

describe "Query" do
	test "processSpecification", %{inserted: new} do
		assert %{data: %{"processSpecification" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					processSpecification(id: $id) {...processSpecification}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
	end
end

describe "Mutation" do
	test "createProcessSpecification", %{params: params} do
		assert %{data: %{"createProcessSpecification" => %{"processSpecification" => data}}} =
			run!("""
				#{@frag}
				mutation ($processSpecification: ProcessSpecificationCreateParams!) {
					createProcessSpecification(processSpecification: $processSpecification) {
						processSpecification {...processSpecification}
					}
				}
			""", vars: %{"processSpecification" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
	end

	test "updateProcessSpecification", %{params: params, inserted: old} do
		assert %{data: %{"updateProcessSpecification" => %{"processSpecification" => data}}} =
			run!("""
				#{@frag}
				mutation ($processSpecification: ProcessSpecificationUpdateParams!) {
					updateProcessSpecification(processSpecification: $processSpecification) {
						processSpecification {...processSpecification}
					}
				}
			""", vars: %{"processSpecification" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
	end

	test "deleteProcessSpecification", %{inserted: %{id: id}} do
		assert %{data: %{"deleteProcessSpecification" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteProcessSpecification(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
