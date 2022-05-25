defmodule ZenflowsTest.VF.Satisfaction do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Satisfaction

setup do
	%{params: %{
		note: Factory.uniq("note"),
		satisfied_by_id: Factory.insert!(:event_or_commitment).id,
		satisfies_id: Factory.insert!(:intent).id,
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
test "create Satisfaction", %{params: params} do
	assert {:ok, %Satisfaction{} = satis} =
		params
		|> Satisfaction.chgset()
		|> Repo.insert()

	assert satis.satisfied_by_id == params.satisfied_by_id
	assert satis.satisfies_id == params.satisfies_id
	assert satis.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert satis.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert satis.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert satis.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	assert satis.note == params.note
end

@tag skip: "TODO: fix events in factory"
test "update Satisfaction", %{params: params} do
	assert {:ok, %Satisfaction{} = satis} =
		Factory.insert!(:satisfaction)
		|> Satisfaction.chgset(params)
		|> Repo.update()

	assert satis.satisfied_by_id == params.satisfied_by_id
	assert satis.satisfies_id == params.satisfies_id
	assert satis.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert satis.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert satis.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert satis.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	assert satis.note == params.note
end
end
