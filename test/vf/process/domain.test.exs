defmodule ZenflowsTest.VF.Process.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Plan,
	Process,
	Process.Domain,
	ProcessSpecification,
	Scenario,
}

setup ctx do
	params = %{
		name: Factory.uniq("name"),
		note: Factory.uniq("note"),
		has_beginning: DateTime.utc_now(),
		has_end: DateTime.utc_now(),
		finished: Factory.bool(),
		classified_as: Factory.uniq_list("class"),
		based_on_id: Factory.insert!(:process_specification).id,
		planned_within_id: Factory.insert!(:plan).id,
		nested_in_id: Factory.insert!(:scenario).id,
 	}

	if ctx[:no_insert] do
		%{params: params}
	else
		%{params: params, process: Factory.insert!(:process)}
	end
end

test "by_id/1 returns a Process", %{process: proc} do
	assert %Process{} = Domain.by_id(proc.id)
end

describe "create/1" do
	@tag :no_insert
	test "creates a Process", %{params: params} do
		assert {:ok, %Process{} = proc} = Domain.create(params)

		assert proc.name == params.name
		assert proc.note == params.note
		assert proc.has_beginning == params.has_beginning
		assert proc.has_end == params.has_end
		assert proc.finished == params.finished
		assert proc.classified_as == params.classified_as
		assert proc.based_on_id == params.based_on_id
		assert proc.planned_within_id == params.planned_within_id
		assert proc.nested_in_id == params.nested_in_id
	end

	test "doesn't create a Process with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a Process with valid params", %{params: params, process: old} do
		assert {:ok, %Process{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
		assert new.has_beginning == params.has_beginning
		assert new.has_end == params.has_end
		assert new.finished == params.finished
		assert new.classified_as == params.classified_as
		assert new.based_on_id == params.based_on_id
		assert new.planned_within_id == params.planned_within_id
		assert new.nested_in_id == params.nested_in_id
	end

	test "doesn't update a Process with invalid params", %{process: old} do
		assert {:ok, %Process{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
		assert new.has_beginning == old.has_beginning
		assert new.has_end == old.has_end
		assert new.finished == old.finished
		assert new.classified_as == old.classified_as
		assert new.based_on_id == old.based_on_id
		assert new.planned_within_id == old.planned_within_id
		assert new.nested_in_id == old.nested_in_id
	end
end

test "delete/1 deletes a Process", %{process: %{id: id}} do
	assert {:ok, %Process{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end

describe "preload/2" do
	test "preloads :based_on", %{process: proc} do
		proc = Domain.preload(proc, :based_on)
		assert based_on = %ProcessSpecification{} = proc.based_on
		assert based_on.id == proc.based_on_id
	end

	test "preloads :planned_within", %{process: proc} do
		proc = Domain.preload(proc, :planned_within)
		assert planed_within = %Plan{} = proc.planned_within
		assert planed_within.id == proc.planned_within_id
	end

	test "preloads :nested_in", %{process: proc} do
		proc = Domain.preload(proc, :nested_in)
		assert nested_in = %Scenario{} = proc.nested_in
		assert nested_in.id == proc.nested_in_id
	end
end
end
