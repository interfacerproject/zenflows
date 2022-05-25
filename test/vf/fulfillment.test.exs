defmodule ZenflowsTest.VF.Fulfillment do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Fulfillment

setup do
	%{params: %{
		note: Factory.uniq("note"),
		fulfilled_by_id: Factory.insert!(:economic_event).id,
		fulfills_id: Factory.insert!(:commitment).id,
		resource_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
		effort_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
	}}
end

@tag skip: "TODO: fix events in factory"
test "create Fulfillment", %{params: params} do
	assert {:ok, %Fulfillment{} = fulf} =
		params
		|> Fulfillment.chgset()
		|> Repo.insert()

	assert fulf.note == params.note
	assert fulf.fulfilled_by_id == params.fulfilled_by_id
	assert fulf.fulfills_id == params.fulfills_id
	assert fulf.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert fulf.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert fulf.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert fulf.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
end

@tag skip: "TODO: fix events in factory"
test "update Fulfillment", %{params: params} do
	assert {:ok, %Fulfillment{} = fulf} =
		:fulfillment
		|> Factory.insert!()
		|> Fulfillment.chgset(params)
		|> Repo.update()

	assert fulf.note == params.note
	assert fulf.fulfilled_by_id == params.fulfilled_by_id
	assert fulf.fulfills_id == params.fulfills_id
	assert fulf.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert fulf.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert fulf.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert fulf.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
end
end
