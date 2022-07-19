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

defmodule ZenflowsTest.VF.RoleBehavior.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		role_behavior: Factory.insert!(:role_behavior),
	}
end

describe "Query" do
	test "roleBehavior()", %{role_behavior: role_beh} do
		assert %{data: %{"roleBehavior" => data}} =
			query!("""
				roleBehavior(id: "#{role_beh.id}") {
					id
					name
					note
				}
			""")

		assert data["id"] == role_beh.id
		assert data["name"] == role_beh.name
		assert data["note"] == role_beh.note
	end
end

describe "Mutation" do
	test "createRoleBehavior()", %{params: params} do
		assert %{data: %{"createRoleBehavior" => %{"roleBehavior" => data}}} =
			mutation!("""
				createRoleBehavior(roleBehavior: {
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					roleBehavior {
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

	test "updateRoleBehavior()", %{params: params, role_behavior: role_beh} do
		assert %{data: %{"updateRoleBehavior" => %{"roleBehavior" => data}}} =
			mutation!("""
				updateRoleBehavior(roleBehavior: {
					id: "#{role_beh.id}"
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					roleBehavior {
						id
						name
						note
					}
				}
			""")

		assert data["id"] == role_beh.id
		assert data["name"] == params.name
		assert data["note"] == params.note
	end

	test "deleteRoleBehavior()", %{role_behavior: %{id: id}} do
		assert %{data: %{"deleteRoleBehavior" => true}} =
			mutation!("""
				deleteRoleBehavior(id: "#{id}")
			""")
	end
end
end
