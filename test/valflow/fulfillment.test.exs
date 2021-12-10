defmodule ZenflowsTest.Valflow.Fulfillment do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Fulfillment

setup do
	%{params: %{
		fulfilled_by_id: Factory.insert!(:economic_event).id,
		fulfills_id: Factory.insert!(:commitment).id,
		resource_quantity_id: Factory.insert!(:measure).id,
		effort_quantity_id: Factory.insert!(:measure).id,
		note: Factory.uniq("note"),
	}}
end

test "create Fulfillment", %{params: params} do
	assert {:ok, %Fulfillment{} = fulf} =
		params
		|> Fulfillment.chset()
		|> Repo.insert()

	assert fulf.fulfilled_by_id == params.fulfilled_by_id
	assert fulf.fulfills_id == params.fulfills_id
	assert fulf.resource_quantity_id == params.resource_quantity_id
	assert fulf.effort_quantity_id == params.effort_quantity_id
	assert fulf.note == params.note
end

test "update Fulfillment", %{params: params} do
	assert {:ok, %Fulfillment{} = fulf} =
		:fulfillment
		|> Factory.insert!()
		|> Fulfillment.chset(params)
		|> Repo.update()

	assert fulf.fulfilled_by_id == params.fulfilled_by_id
	assert fulf.fulfills_id == params.fulfills_id
	assert fulf.resource_quantity_id == params.resource_quantity_id
	assert fulf.effort_quantity_id == params.effort_quantity_id
	assert fulf.note == params.note
end
end
