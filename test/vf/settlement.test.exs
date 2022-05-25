defmodule ZenflowsTest.VF.Settlement do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Settlement

setup do
	%{params: %{
		note: Factory.uniq("note"),
		settled_by_id: Factory.insert!(:economic_event).id,
		settles_id: Factory.insert!(:claim).id,
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
test "create Settlement", %{params: params} do
	assert {:ok, %Settlement{} = settl} =
		params
		|> Settlement.chgset()
		|> Repo.insert()

	assert settl.note == params.note
	assert settl.settled_by_id == params.settled_by_id
	assert settl.settles_id == params.settles_id
	assert settl.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert settl.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert settl.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert settl.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
end

@tag skip: "TODO: fix events in factory"
test "update Settlement", %{params: params} do
	assert {:ok, %Settlement{} = settl} =
		:settlement
		|> Factory.insert!()
		|> Settlement.chgset(params)
		|> Repo.update()

	assert settl.note == params.note
	assert settl.settled_by_id == params.settled_by_id
	assert settl.settles_id == params.settles_id
	assert settl.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert settl.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert settl.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert settl.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
end
end
