defmodule ZenflowsTest.Valflow.RecipeExchange do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.RecipeExchange

setup do
	%{params: %{
		note: Factory.uniq("note"),
		name: Factory.uniq("name"),
	}}
end

test "create RecipeExchange", %{params: params} do
	assert {:ok, %RecipeExchange{} = res_exch} =
		params
		|> RecipeExchange.chset()
		|> Repo.insert()

	assert res_exch.name == params.name
	assert res_exch.note == params.note
end

test "update RecipeExchange", %{params: params} do
	assert {:ok, %RecipeExchange{} = res_exch} =
		:recipe_exchange
		|> Factory.insert!()
		|> RecipeExchange.chset(params)
		|> Repo.update()

	assert res_exch.name == params.name
	assert res_exch.note == params.note
end
end
