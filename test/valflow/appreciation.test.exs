defmodule ZenflowsTest.Valflow.Appreciation do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Appreciation

setup do
	%{params: %{
		appreciation_of_id: Factory.insert!(:economic_event).id,
		appreciation_with_id: Factory.insert!(:economic_event).id,
		note: Factory.uniq("note"),
	}}
end

test "create Appreciation", %{params: params} do
	assert {:ok, %Appreciation{} = appr} =
		params
		|> Appreciation.chset()
		|> Repo.insert()

	assert appr.appreciation_of_id == params.appreciation_of_id
	assert appr.appreciation_with_id == params.appreciation_with_id
	assert appr.note == params.note
end

test "update Appreciation", %{params: params} do
	assert {:ok, %Appreciation{} = appr} =
		:appreciation
		|> Factory.insert!()
		|> Appreciation.chset(params)
		|> Repo.update()

	assert appr.appreciation_of_id == params.appreciation_of_id
	assert appr.appreciation_with_id == params.appreciation_with_id
	assert appr.note == params.note
end
end
