# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule ZenflowsTest.VF.EconomicResource.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.{
	Action,
	Agent,
	EconomicResource,
	EconomicResource.Domain,
	Measure,
	ProcessSpecification,
	ProductBatch,
	ResourceSpecification,
	SpatialThing,
	Unit,
}

setup ctx do
	%{id: unit_id} = Factory.insert!(:unit)
	num_val = Factory.float()
	params = %{
		name: Factory.str("name"),
		note: Factory.str("note"),
		#image: Factory.img(),
		tracking_identifier: Factory.str("tracking identifier"),
		classified_as: Factory.str_list("uri"),
		conforms_to_id: Factory.insert!(:resource_specification).id,
		accounting_quantity: %{
			has_unit_id: unit_id,
			has_numerical_value: num_val,
		},
		onhand_quantity:  %{
			has_unit_id: unit_id,
			has_numerical_value: num_val,
		},
		primary_accountable_id: Factory.insert!(:agent).id,
		custodian_id: Factory.insert!(:agent).id,
		stage_id: Factory.insert!(:process_specification).id,
		state_id: Factory.build(:action_id),
		current_location_id: Factory.insert!(:spatial_thing).id,
		lot_id: Factory.insert!(:product_batch).id,
		contained_in_id: Factory.insert!(:economic_resource).id,
		unit_of_effort_id: Factory.insert!(:unit).id,
		okhv: Factory.str("okhv"),
		repo: Factory.uri(),
		version: Factory.str("version"),
		licensor: Factory.str("licensor"),
		license: Factory.str("license"),
		metadata: %{"something" => "something"},
 	}

	if ctx[:no_insert] do
		%{params: params}
	else
		%{params: params, inserted: Factory.insert!(:economic_resource)}
	end
end

test "by_id/1 returns a EconomicResource", %{inserted: eco_res} do
	assert {:ok, %EconomicResource{}} = Domain.one(eco_res.id)
end

test "classifications/0 returns list of unique `classified_as` values" do
	Enum.each(1..10, fn _ -> Factory.insert!(:economic_resource) end)
	left = Enum.flat_map(Domain.all!(), & &1.classified_as)
	right = Domain.classifications()
	assert [] = left -- right
end

describe "update/2" do
	@tag skip: "TODO: fix economic resource factory"
	test "doesn't update a EconomicResource", %{inserted: old} do
		assert {:ok, %EconomicResource{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.primary_accountable_id == old.primary_accountable_id
		assert new.custodian_id == old.custodian_id
		assert new.classified_as == old.classified_as
		assert new.conforms_to_id == old.conforms_to_id
		assert new.tracking_identifier == old.tracking_identifier
		assert new.lot_id == old.lot_id
		assert new.accounting_quantity_has_unit_id == old.accounting_quantity_has_unit_id
		assert new.accounting_quantity_has_numerical_value == old.accounting_quantity_has_numerical_value
		assert new.onhand_quantity_has_unit_id == old.onhand_quantity_has_unit_id
		assert new.onhand_quantity_has_numerical_value == old.onhand_quantity_has_numerical_value
		assert new.current_location_id == old.current_location_id
		assert new.note == old.note
		#assert new.image == old.image
		assert new.unit_of_effort_id == old.unit_of_effort_id
		assert new.stage_id == old.stage_id
		assert new.state_id == old.state_id
		assert new.contained_in_id == old.contained_in_id
	end

	@tag skip: "TODO: fix economic resource factory"
	test "updates a EconomicResource with valid params", %{params: params, inserted: old} do
		assert {:ok, %EconomicResource{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.primary_accountable_id == params.primary_accountable_id
		assert new.custodian_id == params.custodian_id
		assert new.classified_as == params.classified_as
		assert new.conforms_to_id == params.conforms_to_id
		assert new.tracking_identifier == params.tracking_identifier
		assert new.lot_id == params.lot_id
		assert new.accounting_quantity_has_unit_id == params.accounting_quantity.has_unit_id
		assert new.accounting_quantity_has_numerical_value == params.accounting_quantity.has_numerical_value
		assert new.onhand_quantity_has_unit_id == params.onhand_quantity.has_unit_id
		assert new.onhand_quantity_has_numerical_value == params.onhand_quantity.has_numerical_value
		assert new.current_location_id == params.current_location_id
		assert new.note == params.note
		#assert new.image == params.image
		assert new.unit_of_effort_id == params.unit_of_effort_id
		assert new.stage_id == params.stage_id
		assert new.state_id == params.state_id
		assert new.contained_in_id == params.contained_in_id
	end
end

@tag skip: "TODO: needs to deal with previous_event_id"
test "delete/1 deletes a EconomicResource", %{inserted: %{id: id}} do
	assert {:ok, %EconomicResource{id: ^id}} = Domain.delete(id)
	assert {:error, "not found"} = Domain.one(id)
end

describe "preload/2" do
	test "preloads :conforms_to", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :conforms_to)
		assert confo_to = %ResourceSpecification{} = eco_res.conforms_to
		assert confo_to.id == eco_res.conforms_to_id
	end

	test "preloads :accounting_quantity", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :accounting_quantity)
		assert accnt_qty = %Measure{} = eco_res.accounting_quantity
		assert accnt_qty.has_unit_id == eco_res.accounting_quantity_has_unit_id
		assert accnt_qty.has_numerical_value == eco_res.accounting_quantity_has_numerical_value
	end

	test "preloads :onhand_quantity", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :onhand_quantity)
		assert onhnd_qty = %Measure{} = eco_res.onhand_quantity
		assert onhnd_qty.has_unit_id == eco_res.onhand_quantity_has_unit_id
		assert onhnd_qty.has_numerical_value == eco_res.onhand_quantity_has_numerical_value
	end

	test "preloads :primary_accountable", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :primary_accountable)
		assert pri_accnt = %Agent{} = eco_res.primary_accountable
		assert pri_accnt.id == eco_res.primary_accountable_id
	end

	test "preloads :custodian", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :custodian)
		assert custo = %Agent{} = eco_res.custodian
		assert custo.id == eco_res.custodian_id
	end

	@tag skip: "TODO: fix EconomicResource factory"
	test "preloads :stage", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :stage)
		assert stage = %ProcessSpecification{} = eco_res.stage
		assert stage.id == eco_res.stage_id
	end

	@tag skip: "TODO: fix EconomicResource factory"
	test "preloads :state", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :state)
		assert action = %Action{} = eco_res.state
		assert action.id == eco_res.state_id
	end

	@tag skip: "TODO: fix EconomicResource factory"
	test "preloads :current_location", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :current_location)
		assert cur_loc = %SpatialThing{} = eco_res.current_location
		assert cur_loc.id == eco_res.current_location_id
	end

	@tag skip: "TODO: fix EconomicResource factory"
	test "preloads :lot", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :lot)
		assert lot = %ProductBatch{} = eco_res.lot
		assert lot.id == eco_res.lot_id
	end

	test "preloads :contained_in", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :contained_in)
		if eco_res.contained_in do
			assert cont_in = %EconomicResource{} = eco_res.contained_in
			assert cont_in.id == eco_res.contained_in_id
		end
	end

	@tag skip: "TODO: fix EconomicResource factory"
	test "preloads :unit_of_effort", %{inserted: eco_res} do
		eco_res = Domain.preload(eco_res, :unit_of_effort)
		assert unit_eff = %Unit{} = eco_res.unit_of_effort
		assert unit_eff.id == eco_res.unit_of_effort_id
	end
end
end
