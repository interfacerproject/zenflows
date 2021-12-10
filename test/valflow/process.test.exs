defmodule ZenflowsTest.Valflow.Process do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Process

setup do
	%{params: %{
		name: Factory.uniq("name"),
		has_beginning: DateTime.utc_now(),
		has_end: DateTime.utc_now(),
		finished: Factory.bool(),
		note: Factory.uniq("note"),
		classified_as: Factory.uniq_list("class"),
		based_on_id: Factory.insert!(:process_specification).id,
		planned_within_id: Factory.insert!(:plan).id,
		nested_in_id: Factory.insert!(:scenario).id,
	}}
end

test "create Process", %{params: params} do
	assert {:ok, %Process{} = proc} =
		params
		|> Process.chset()
		|> Repo.insert()

	assert proc.name == params.name
	assert proc.has_beginning == params.has_beginning
	assert proc.has_end == params.has_end
	assert proc.finished == params.finished
	assert proc.note == params.note
	assert proc.classified_as == params.classified_as
	assert proc.based_on_id == params.based_on_id
	assert proc.planned_within_id == params.planned_within_id
	assert proc.nested_in_id == params.nested_in_id
end

test "update Process", %{params: params} do
	assert {:ok, %Process{} = proc} =
		:process
		|> Factory.insert!()
		|> Process.chset(params)
		|> Repo.update()

	assert proc.name == params.name
	assert proc.has_beginning == params.has_beginning
	assert proc.has_end == params.has_end
	assert proc.finished == params.finished
	assert proc.note == params.note
	assert proc.classified_as == params.classified_as
	assert proc.based_on_id == params.based_on_id
	assert proc.planned_within_id == params.planned_within_id
	assert proc.nested_in_id == params.nested_in_id
end
end
