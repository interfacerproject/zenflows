defmodule ZenflowsTest.VF.Agreement.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Agreement, Agreement.Domain}

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			created: DateTime.utc_now(),
		},
		inserted: Factory.insert!(:agreement),
	}
end

test "by_id/1 returns a Agreement", %{inserted: agreem} do
	assert %Agreement{} = Domain.by_id(agreem.id)
end

describe "create/1" do
	test "creates a Agreement with valid params", %{params: params} do
		assert {:ok, %Agreement{} = agreem} = Domain.create(params)

		assert agreem.name == params.name
		assert agreem.note == params.note
		assert agreem.created == params.created
	end

	test "doesn't create a Agreement with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a Agreement with valid params", %{params: params, inserted: old} do
		assert {:ok, %Agreement{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
		assert new.created == params.created
	end

	test "doesn't update a Agreement", %{inserted: old} do
		assert {:ok, %Agreement{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
		assert new.created == old.created
	end
end

test "delete/1 deletes a Agreement", %{inserted: %{id: id}} do
	assert {:ok, %Agreement{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
