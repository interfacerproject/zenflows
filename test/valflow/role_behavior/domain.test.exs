defmodule ZenflowsTest.Valflow.RoleBehavior.Domain do
use ZenflowsTest.Case.Repo, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.{RoleBehavior, RoleBehavior.Domain}

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		role_behavior: Factory.insert!(:role_behavior),
	}
end

test "by_id/1 returns a RoleBehavior", %{role_behavior: role_beh} do
	assert %RoleBehavior{} = Domain.by_id(role_beh.id)
end

describe "create/1" do
	test "creates a RoleBehavior with valid params", %{params: params} do
		assert {:ok, %RoleBehavior{} = role_beh} = Domain.create(params)

		assert role_beh.name == params.name
		assert role_beh.note == params.note
	end

	test "doesn't create a RoleBehavior with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a RoleBehavior with valid params", %{params: params, role_behavior: old} do
		assert {:ok, %RoleBehavior{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
	end

	test "doesn't update a RoleBehavior", %{role_behavior: old} do
		assert {:ok, %RoleBehavior{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
	end
end

test "delete/1 deletes a RoleBehavior", %{role_behavior: %{id: id}} do
	assert {:ok, %RoleBehavior{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
