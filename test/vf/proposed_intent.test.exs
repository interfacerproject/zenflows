defmodule ZenflowsTest.VF.ProposedIntent do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.ProposedIntent

setup do
	%{params: %{
		reciprocal: Factory.bool(),
		publishes_id: Factory.insert!(:intent).id,
		published_in_id: Factory.insert!(:proposal).id,
	}}
end

test "create ProposedIntent", %{params: params} do
	assert {:ok, %ProposedIntent{} = prop_int} =
		params
		|> ProposedIntent.chgset()
		|> Repo.insert()

	assert prop_int.reciprocal == params.reciprocal
	assert prop_int.publishes_id == params.publishes_id
	assert prop_int.published_in_id == params.published_in_id
end

test "update ProposedIntent", %{params: params} do
	assert {:ok, %ProposedIntent{} = prop_int} =
		:proposed_intent
		|> Factory.insert!()
		|> ProposedIntent.chgset(params)
		|> Repo.update()

	assert prop_int.reciprocal == params.reciprocal
	assert prop_int.publishes_id == params.publishes_id
	assert prop_int.published_in_id == params.published_in_id
end
end
