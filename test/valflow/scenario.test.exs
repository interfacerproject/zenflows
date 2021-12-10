defmodule ZenflowsTest.Valflow.Scenario do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Scenario

setup do
	%{params: %{
		name: Factory.uniq("name"),
		has_beginning: DateTime.utc_now(),
		has_end: DateTime.utc_now(),
		defined_as_id: Factory.insert!(:scenario_definition).id,
		refinement_of_id: Factory.insert!(:scenario).id,
		note: Factory.uniq("note"),
	}}
end

test "create Scenario", %{params: params} do
	assert {:ok, %Scenario{} = scen} =
		params
		|> Scenario.chset()
		|> Repo.insert()

	assert scen.name == params.name
	assert scen.has_beginning == params.has_beginning
	assert scen.has_end == params.has_end
	assert scen.defined_as_id == params.defined_as_id
	assert scen.refinement_of_id == params.refinement_of_id
	assert scen.note == params.note
end

test "update Scenario", %{params: params} do
	assert {:ok, %Scenario{} = scen} =
		:scenario
		|> Factory.insert!()
		|> Scenario.chset(params)
		|> Repo.update()

	assert scen.name == params.name
	assert scen.has_beginning == params.has_beginning
	assert scen.has_end == params.has_end
	assert scen.defined_as_id == params.defined_as_id
	assert scen.refinement_of_id == params.refinement_of_id
	assert scen.note == params.note
end
end
