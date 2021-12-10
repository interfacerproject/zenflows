defmodule ZenflowsTest.Valflow.ScenarioDefinition do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.ScenarioDefinition

setup do
	%{params: %{
		name: Factory.uniq("name"),
		note: Factory.uniq("note"),
		has_duration_id: Factory.insert!(:duration).id,
	}}
end

test "create ScenarioDefinition", %{params: params} do
	assert {:ok, %ScenarioDefinition{} = scen_def} =
		params
		|> ScenarioDefinition.chset()
		|> Repo.insert()

	assert scen_def.name == params.name
	assert scen_def.note == params.note
	assert scen_def.has_duration_id == params.has_duration_id
end

test "update ScenarioDefinition", %{params: params} do
	assert {:ok, %ScenarioDefinition{} = scen_def} =
		:scenario_definition
		|> Factory.insert!()
		|> ScenarioDefinition.chset(params)
		|> Repo.update()

	assert scen_def.name == params.name
	assert scen_def.note == params.note
	assert scen_def.has_duration_id == params.has_duration_id
end
end
