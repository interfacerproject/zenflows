defmodule ZenflowsTest.Valflow.AgentRelationshipRole.Domain do
use ZenflowsTest.Case.Repo, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.{AgentRelationshipRole, AgentRelationshipRole.Domain}

setup do
	%{
		params: %{
			role_behavior_id: Factory.insert!(:role_behavior).id,
			role_label: Factory.uniq("role label"),
			inverse_role_label: Factory.uniq("inverse role label"),
			note: Factory.uniq("note"),
		},
		agent_relationship_role: Factory.insert!(:agent_relationship_role),
	}
end

test "by_id/1 returns an AgentRelationshipRole", %{agent_relationship_role: rel_role} do
	assert %AgentRelationshipRole{} = Domain.by_id(rel_role.id)
end

describe "create/1" do
	test "creates an AgentRelationshipRole with valid params", %{params: params} do
		assert {:ok, %AgentRelationshipRole{} = rel_role} = Domain.create(params)

		assert rel_role.role_behavior_id == params.role_behavior_id
		assert rel_role.role_label == params.role_label
		assert rel_role.inverse_role_label == params.inverse_role_label
		assert rel_role.note == params.note
	end

	test "doesn't create an AgentRelationshipRole with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates an AgentRelationshipRole with valid params", %{params: params, agent_relationship_role: old} do
		assert {:ok, %AgentRelationshipRole{} = new} = Domain.update(old.id, params)

		assert new.role_behavior_id == params.role_behavior_id
		assert new.role_label == params.role_label
		assert new.inverse_role_label == params.inverse_role_label
		assert new.note == params.note
	end

	test "doesn't update an AgentRelationshipRole", %{agent_relationship_role: old} do
		assert {:ok, %AgentRelationshipRole{} = new} = Domain.update(old.id, %{})

		assert new.role_behavior_id == old.role_behavior_id
		assert new.role_label == old.role_label
		assert new.inverse_role_label == old.inverse_role_label
		assert new.note == old.note
	end
end

test "delete/1 deletes an AgentRelationshipRole", %{agent_relationship_role: %{id: id}} do
	assert {:ok, %AgentRelationshipRole{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
