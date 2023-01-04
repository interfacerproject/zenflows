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

defmodule ZenflowsTest.VF.AgentRelationship.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"subject" => Factory.insert!(:agent).id,
			"object" => Factory.insert!(:agent).id,
			"relationship" => Factory.insert!(:agent_relationship_role).id,
			# inScopeOf:
			"note" => Factory.str("note"),
		},
		inserted: Factory.insert!(:agent_relationship),
	}
end

@frag """
fragment agentRelationship on AgentRelationship {
	id
	subject { id }
	object { id }
	relationship { id }
	note
}
"""

describe "Query" do
	test "agentRelationship", %{inserted: new} do
		assert %{data: %{"agentRelationship" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					agentRelationship(id: $id) {...agentRelationship}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["subject"]["id"] == new.subject_id
		assert data["object"]["id"] == new.object_id
		assert data["relationship"]["id"] == new.relationship_id
		assert data["note"] == new.note
	end
end

describe "Mutation" do
	test "createAgentRelationship", %{params: params} do
		assert %{data: %{"createAgentRelationship" => %{"agentRelationship" => data}}} =
			run!("""
				#{@frag}
				mutation ($relationship: AgentRelationshipCreateParams!) {
					createAgentRelationship(relationship: $relationship) {
						agentRelationship {...agentRelationship}
					}
				}
			""", vars: %{"relationship" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["subject"]["id"] == params["subject"]
		assert data["object"]["id"] == params["object"]
		assert data["relationship"]["id"] == params["relationship"]
		assert data["note"] == params["note"]
	end

	test "updateAgentRelationship", %{params: params, inserted: old} do
		assert %{data: %{"updateAgentRelationship" => %{"agentRelationship" => data}}} =
			run!("""
				#{@frag}
				mutation ($relationship: AgentRelationshipUpdateParams!) {
					updateAgentRelationship(relationship: $relationship) {
						agentRelationship {...agentRelationship}
					}
				}
			""", vars: %{"relationship" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		assert data["subject"]["id"] == params["subject"]
		assert data["object"]["id"] == params["object"]
		assert data["relationship"]["id"] == params["relationship"]
		assert data["note"] == params["note"]
	end

	test "deleteAgentRelationship", %{inserted: %{id: id}} do
		assert %{data: %{"deleteAgentRelationship" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteAgentRelationship(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
