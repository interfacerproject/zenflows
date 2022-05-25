defmodule ZenflowsTest.VF.AgentRelationship.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{AgentRelationship, AgentRelationship.Domain}

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

test "by_id/1 returns an AgentRelationship", %{agent_relationship: rel} do
	assert %AgentRelationship{} = Domain.by_id(rel.id)
end

describe "create/1" do
	test "creates an AgentRelationship with valid params", %{params: params} do
		assert {:ok, %AgentRelationship{} = rel} = Domain.create(params)

		assert rel.subject_id == params.subject_id
		assert rel.object_id == params.object_id
		assert rel.relationship_id == params.relationship_id
		assert rel.note == params.note
	end

	test "doesn't create a AgentRelationship with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates an AgentRelationship with valid params", %{params: params, agent_relationship: old} do
		assert {:ok, %AgentRelationship{} = new} = Domain.update(old.id, params)

		assert new.subject_id == params.subject_id
		assert new.object_id == params.object_id
		assert new.relationship_id == params.relationship_id
		assert new.note == params.note
	end

	test "doesn't update a AgentRelationship", %{agent_relationship: old} do
		assert {:ok, %AgentRelationship{} = new} = Domain.update(old.id, %{})

		assert new.subject_id == old.subject_id
		assert new.object_id == old.object_id
		assert new.relationship_id == old.relationship_id
		assert new.note == old.note
	end
end

test "delete/1 deletes an AgentRelationship", %{agent_relationship: %{id: id}} do
	assert {:ok, %AgentRelationship{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
