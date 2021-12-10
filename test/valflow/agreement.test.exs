defmodule ZenflowsTest.Valflow.Agreement do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Agreement

setup do
	%{params: %{
		name: Factory.uniq("name"),
		created: DateTime.utc_now(),
		note: Factory.uniq("note"),
	}}
end

test "create Agreement", %{params: params} do
	assert {:ok, %Agreement{} = agreem} =
		params
		|> Agreement.chset()
		|> Repo.insert()

	assert agreem.name == params.name
	assert agreem.created == params.created
	assert agreem.note == params.note
end

test "update Agreement", %{params: params} do
	assert {:ok, %Agreement{} = agreem} =
		:agreement
		|> Factory.insert!()
		|> Agreement.chset(params)
		|> Repo.update()

	assert agreem.name == params.name
	assert agreem.created == params.created
	assert agreem.note == params.note
end
end
