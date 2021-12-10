defmodule ZenflowsTest.Valflow.Plan do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Plan

setup do
	%{params: %{
		name: Factory.uniq("name"),
		created: DateTime.utc_now(),
		due: DateTime.utc_now(),
		note: Factory.uniq("note"),
		refinement_of_id: Factory.insert!(:scenario).id,
	}}
end

test "create Plan", %{params: params} do
	assert {:ok, %Plan{} = plan} =
		params
		|> Plan.chset()
		|> Repo.insert()

	assert plan.name == params.name
	assert plan.created == params.created
	assert plan.due == params.due
	assert plan.note == params.note
	assert plan.refinement_of_id == params.refinement_of_id
end

test "update Plan", %{params: params} do
	assert {:ok, %Plan{} = plan} =
		:plan
		|> Factory.insert!()
		|> Plan.chset(params)
		|> Repo.update()

	assert plan.name == params.name
	assert plan.created == params.created
	assert plan.due == params.due
	assert plan.note == params.note
	assert plan.refinement_of_id == params.refinement_of_id
end
end
