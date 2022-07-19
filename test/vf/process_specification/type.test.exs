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
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		process_specification: Factory.insert!(:process_specification),
	}
end

describe "Query" do
	test "processSpecification()", %{process_specification: proc_spec} do
		assert %{data: %{"processSpecification" => data}} =
			query!("""
				processSpecification(id: "#{proc_spec.id}") {
					id
					name
					note
				}
			""")

		assert data["id"] == proc_spec.id
		assert data["name"] == proc_spec.name
		assert data["note"] == proc_spec.note
	end
end

describe "Mutation" do
	test "createProcessSpecification()", %{params: params} do
		assert %{data: %{"createProcessSpecification" => %{"processSpecification" => data}}} =
			mutation!("""
				createProcessSpecification(processSpecification: {
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					processSpecification {
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

	test "updateProcessSpecification()", %{params: params, process_specification: proc_spec} do
		assert %{data: %{"updateProcessSpecification" => %{"processSpecification" => data}}} =
			mutation!("""
				updateProcessSpecification(processSpecification: {
					id: "#{proc_spec.id}"
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					processSpecification {
						id
						name
						note
					}
				}
			""")

		assert data["id"] == proc_spec.id
		assert data["name"] == params.name
		assert data["note"] == params.note
	end

	test "deleteProcessSpecification()", %{process_specification: %{id: id}} do
		assert %{data: %{"deleteProcessSpecification" => true}} =
			mutation!("""
				deleteProcessSpecification(id: "#{id}")
			""")
	end
end
end
