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
			"name" => Factory.uniq("name"),
			"note" => Factory.uniq("note"),
		},
		inserted: Factory.insert!(:role_behavior),
	}
end

@frag """
fragment roleBehavior on RoleBehavior {
	id
	name
	note
}
"""

describe "Query" do
	test "roleBehavior", %{inserted: new} do
		assert %{data: %{"roleBehavior" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					roleBehavior(id: $id) {...roleBehavior}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
	end
end

describe "Mutation" do
	test "createRoleBehavior", %{params: params} do
		assert %{data: %{"createRoleBehavior" => %{"roleBehavior" => data}}} =
			run!("""
				#{@frag}
				mutation ($roleBehavior: RoleBehaviorCreateParams!) {
					createRoleBehavior(roleBehavior: $roleBehavior) {
						roleBehavior {...roleBehavior}
					}
				}
			""", vars: %{"roleBehavior" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
	end

	test "updateRoleBehavior", %{params: params, inserted: old} do
		assert %{data: %{"updateRoleBehavior" => %{"roleBehavior" => data}}} =
			run!("""
				#{@frag}
				mutation ($roleBehavior: RoleBehaviorUpdateParams!) {
					updateRoleBehavior(roleBehavior: $roleBehavior) {
						roleBehavior {...roleBehavior}
					}
				}
			""", vars: %{"roleBehavior" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		assert data["name"] == params["name"]
		assert data["note"] == params["note"]
	end

	test "deleteRoleBehavior", %{inserted: %{id: id}} do
		assert %{data: %{"deleteRoleBehavior" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteRoleBehavior(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
