defmodule ZenflowsTest.VF.Appreciation do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Appreciation

setup do
	%{params: %{
		appreciation_of_id: Factory.insert!(:economic_event).id,
		appreciation_with_id: Factory.insert!(:economic_event).id,
		note: Factory.uniq("note"),
	}}
end

@tag skip: "TODO: fix events in factory"
test "create Appreciation", %{params: params} do
	assert {:ok, %Appreciation{} = appr} =
		params
		|> Appreciation.chgset()
		|> Repo.insert()

	assert appr.appreciation_of_id == params.appreciation_of_id
	assert appr.appreciation_with_id == params.appreciation_with_id
	assert appr.note == params.note
end

@tag skip: "TODO: fix events in factory"
test "update Appreciation", %{params: params} do
	assert {:ok, %Appreciation{} = appr} =
		:appreciation
		|> Factory.insert!()
		|> Appreciation.chgset(params)
		|> Repo.update()

	assert appr.appreciation_of_id == params.appreciation_of_id
	assert appr.appreciation_with_id == params.appreciation_with_id
	assert appr.note == params.note
end
end
