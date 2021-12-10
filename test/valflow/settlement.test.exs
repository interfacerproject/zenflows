defmodule ZenflowsTest.Valflow.Settlement do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Settlement

setup do
	%{params: %{
		settled_by_id: Factory.insert!(:economic_event).id,
		settles_id: Factory.insert!(:claim).id,
		resource_quantity_id: Factory.insert!(:measure).id,
		effort_quantity_id: Factory.insert!(:measure).id,
		note: Factory.uniq("note"),
	}}
end

test "create Settlement", %{params: params} do
	assert {:ok, %Settlement{} = settl} =
		params
		|> Settlement.chset()
		|> Repo.insert()

	assert settl.settled_by_id == params.settled_by_id
	assert settl.settles_id == params.settles_id
	assert settl.resource_quantity_id == params.resource_quantity_id
	assert settl.effort_quantity_id == params.effort_quantity_id
	assert settl.note == params.note
end

test "update Settlement", %{params: params} do
	assert {:ok, %Settlement{} = settl} =
		:settlement
		|> Factory.insert!()
		|> Settlement.chset(params)
		|> Repo.update()

	assert settl.settled_by_id == params.settled_by_id
	assert settl.settles_id == params.settles_id
	assert settl.resource_quantity_id == params.resource_quantity_id
	assert settl.effort_quantity_id == params.effort_quantity_id
	assert settl.note == params.note
end
end
