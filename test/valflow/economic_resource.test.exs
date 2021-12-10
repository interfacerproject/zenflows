defmodule ZenflowsTest.Valflow.EconomicResource do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.EconomicResource

setup do
	%{params: %{
		name: Factory.uniq("name"),
		primary_accountable_id: Factory.insert!(:agent).id,
		classified_as: Factory.uniq_list("uri"),
		conforms_to_id: Factory.insert!(:resource_specification).id,
		tracking_identifier: Factory.uniq("tracking identifier"),
		lot_id: Factory.insert!(:product_batch).id,
		accounting_quantity_id: Factory.insert!(:measure).id,
		onhand_quantity_id: Factory.insert!(:measure).id,
		current_location_id: Factory.insert!(:spatial_thing).id,
		note: Factory.uniq("note"),
		image: Factory.uri(),
		unit_of_effort_id: Factory.insert!(:unit).id,
		stage_id: Factory.insert!(:process_specification).id,
		state: Factory.build(:action_enum),
		contained_in_id: Factory.insert!(:economic_resource).id,
	}}
end

test "create EconomicResource", %{params: params} do
	assert {:ok, %EconomicResource{} = eco_res} =
		params
		|> EconomicResource.chset()
		|> Repo.insert()

	assert eco_res.name == params.name
	assert eco_res.primary_accountable_id == params.primary_accountable_id
	assert eco_res.classified_as == params.classified_as
	assert eco_res.conforms_to_id == params.conforms_to_id
	assert eco_res.tracking_identifier == params.tracking_identifier
	assert eco_res.lot_id == params.lot_id
	assert eco_res.accounting_quantity_id == params.accounting_quantity_id
	assert eco_res.onhand_quantity_id == params.onhand_quantity_id
	assert eco_res.current_location_id == params.current_location_id
	assert eco_res.note == params.note
	assert eco_res.image == params.image
	assert eco_res.unit_of_effort_id == params.unit_of_effort_id
	assert eco_res.stage_id == params.stage_id
	assert eco_res.state == params.state
	assert eco_res.contained_in_id == params.contained_in_id
end

test "update EconomicResource", %{params: params} do
	assert {:ok, %EconomicResource{} = eco_res} =
		:economic_resource
		|> Factory.insert!()
		|> EconomicResource.chset(params)
		|> Repo.update()

	assert eco_res.name == params.name
	assert eco_res.primary_accountable_id == params.primary_accountable_id
	assert eco_res.classified_as == params.classified_as
	assert eco_res.conforms_to_id == params.conforms_to_id
	assert eco_res.tracking_identifier == params.tracking_identifier
	assert eco_res.lot_id == params.lot_id
	assert eco_res.accounting_quantity_id == params.accounting_quantity_id
	assert eco_res.onhand_quantity_id == params.onhand_quantity_id
	assert eco_res.current_location_id == params.current_location_id
	assert eco_res.note == params.note
	assert eco_res.image == params.image
	assert eco_res.unit_of_effort_id == params.unit_of_effort_id
	assert eco_res.stage_id == params.stage_id
	assert eco_res.state == params.state
	assert eco_res.contained_in_id == params.contained_in_id
end
end
