defmodule ZenflowsTest.Valflow.AgentRelationship.Type do
use ZenflowsTest.Case.Absin, async: true

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

		assert {:ok, _} = Zenflows.Ecto.Id.cast(data["id"])
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
