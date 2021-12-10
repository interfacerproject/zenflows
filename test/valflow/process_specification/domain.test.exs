defmodule ZenflowsTest.Valflow.ProcessSpecification.Domain do
use ZenflowsTest.Case.Repo, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.{ProcessSpecification, ProcessSpecification.Domain}

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		process_specification: Factory.insert!(:process_specification),
	}
end

test "by_id/1 returns a ProcessSpecification", %{process_specification: proc_spec} do
	assert %ProcessSpecification{} = Domain.by_id(proc_spec.id)
end

describe "create/1" do
	test "creates a ProcessSpecification with valid params", %{params: params} do
		assert {:ok, %ProcessSpecification{} = proc_spec} = Domain.create(params)

		assert proc_spec.name == params.name
		assert proc_spec.note == params.note
	end

	test "doesn't create a ProcessSpecification with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a ProcessSpecification with valid params", %{params: params, process_specification: old} do
		assert {:ok, %ProcessSpecification{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
	end

	test "doesn't update a ProcessSpecification", %{process_specification: old} do
		assert {:ok, %ProcessSpecification{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
	end
end

test "delete/1 deletes a ProcessSpecification", %{process_specification: %{id: id}} do
	assert {:ok, %ProcessSpecification{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
