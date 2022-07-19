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

defmodule ZenflowsTest.VF.AgentRelationship.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			subject_id: Factory.insert!(:agent).id,
			object_id: Factory.insert!(:agent).id,
			relationship_id: Factory.insert!(:agent_relationship_role).id,
			# in_scope_of:
			note: Factory.uniq("note"),
		},
		agent_relationship: Factory.insert!(:agent_relationship),
	}
end

describe "Query" do
	test "agentRelationship()", %{agent_relationship: rel} do
		assert %{data: %{"agentRelationship" => data}} =
			query!("""
				agentRelationship(id: "#{rel.id}") {
					id
					subject { id }
					object { id }
					relationship {
						id
					}
					note
				}
			""")

		assert data["id"] == rel.id
		assert data["subject"]["id"] == rel.subject_id
		assert data["object"]["id"] == rel.object_id
		assert data["relationship"]["id"] == rel.relationship_id
		assert data["note"] == rel.note
	end
end

describe "Mutation" do
	test "createAgentRelationship()", %{params: params} do
		assert %{data: %{"createAgentRelationship" => %{"agentRelationship" => data}}} =
			mutation!("""
				createAgentRelationship(relationship: {
					subject: "#{params.subject_id}"
					object: "#{params.object_id}"
					relationship: "#{params.relationship_id}"
					note: "#{params.note}"
				}) {
					agentRelationship {
						id
						subject { id }
						object { id }
						relationship { id }
						note
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["subject"]["id"] == params.subject_id
		assert data["object"]["id"] == params.object_id
		assert data["relationship"]["id"] == params.relationship_id
		assert data["note"] == params.note
	end

	test "updateAgentRelationship()", %{params: params, agent_relationship: rel} do
		assert %{data: %{"updateAgentRelationship" => %{"agentRelationship" => data}}} =
			mutation!("""
				updateAgentRelationship(relationship: {
					id: "#{rel.id}"
					subject: "#{params.subject_id}"
					object: "#{params.object_id}"
					relationship: "#{params.relationship_id}"
					note: "#{params.note}"
				}) {
					agentRelationship {
						id
						subject { id }
						object { id }
						relationship { id }
						note
					}
				}
			""")

		assert data["id"] == rel.id
		assert data["subject"]["id"] == params.subject_id
		assert data["object"]["id"] == params.object_id
		assert data["relationship"]["id"] == params.relationship_id
		assert data["note"] == params.note
	end

	test "deleteAgentRelationship()", %{agent_relationship: %{id: id}} do
		assert %{data: %{"deleteAgentRelationship" => true}} =
			mutation!("""
				deleteAgentRelationship(id: "#{id}")
			""")
	end
end
end
