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

defmodule ZenflowsTest.VF.AgentRelationshipRole.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"roleBehavior" => Factory.insert!(:role_behavior).id,
			"roleLabel" => Factory.str("role label"),
			"inverseRoleLabel" => Factory.str("inverse role label"),
			"note" => Factory.str("note"),
		},
		inserted: Factory.insert!(:agent_relationship_role),
	}
end

@frag """
fragment agentRelationshipRole on AgentRelationshipRole {
	id
	roleBehavior { id }
	roleLabel
	inverseRoleLabel
	note
}
"""

describe "Query" do
	test "agentRelationshipRole", %{inserted: new} do
		assert %{data: %{"agentRelationshipRole" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					agentRelationshipRole(id: $id) {...agentRelationshipRole}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["roleBehavior"]["id"] == new.role_behavior_id
		assert data["roleLabel"] == new.role_label
		assert data["inverseRoleLabel"] == new.inverse_role_label
		assert data["note"] == new.note
	end
end

describe "Mutation" do
	test "createAgentRelationshipRole", %{params: params} do
		assert %{data: %{"createAgentRelationshipRole" => %{"agentRelationshipRole" => data}}} =
			run!("""
				#{@frag}
				mutation ($agentRelationshipRole: AgentRelationshipRoleCreateParams!) {
					createAgentRelationshipRole(agentRelationshipRole: $agentRelationshipRole) {
						agentRelationshipRole {...agentRelationshipRole}
					}
				}
			""", vars: %{"agentRelationshipRole" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["roleBehavior"]["id"] == params["roleBehavior"]
		assert data["roleLabel"] == params["roleLabel"]
		assert data["inverseRoleLabel"] == params["inverseRoleLabel"]
		assert data["note"] == params["note"]
	end

	test "updateAgentRelationshipRole", %{params: params, inserted: old} do
		assert %{data: %{"updateAgentRelationshipRole" => %{"agentRelationshipRole" => data}}} =
			run!("""
				#{@frag}
				mutation ($agentRelationshipRole: AgentRelationshipRoleUpdateParams!) {
					updateAgentRelationshipRole(agentRelationshipRole: $agentRelationshipRole) {
						agentRelationshipRole {...agentRelationshipRole}
					}
				}
			""", vars: %{"agentRelationshipRole" => Map.put(params, "id", old.id)})
		assert data["id"] == old.id
		assert data["roleBehavior"]["id"] == params["roleBehavior"]
		assert data["roleLabel"] == params["roleLabel"]
		assert data["inverseRoleLabel"] == params["inverseRoleLabel"]
		assert data["note"] == params["note"]
	end

	test "deleteAgentRelationshipRole()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteAgentRelationshipRole" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteAgentRelationshipRole(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
