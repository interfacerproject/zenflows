defmodule ZenflowsTest.Valflow.ProposedTo do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.ProposedTo

setup do
	%{params: %{
		proposed_to_id: Factory.insert!(:agent).id,
		proposed_id: Factory.insert!(:proposal).id,
	}}
end

test "create ProposedTo", %{params: params} do
	assert {:ok, %ProposedTo{} = prop_to} =
		params
		|> ProposedTo.chset()
		|> Repo.insert()

	assert prop_to.proposed_to_id == params.proposed_to_id
	assert prop_to.proposed_id == params.proposed_id
end

test "update ProposedTo", %{params: params} do
	assert {:ok, %ProposedTo{} = prop_to} =
		:proposed_to
		|> Factory.insert!()
		|> ProposedTo.chset(params)
		|> Repo.update()

	assert prop_to.proposed_to_id == params.proposed_to_id
	assert prop_to.proposed_id == params.proposed_id
end
end
