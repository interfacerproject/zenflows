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

defmodule ZenflowsTest.VF.Commitment do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.Commitment

setup do
	%{params: %{
		action_id: Factory.build(:action_id),
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		input_of_id: Factory.insert!(:process).id,
		output_of_id: Factory.insert!(:process).id,
		resource_classified_as: Factory.uniq_list("uri"),
		resource_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
		effort_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
		due: DateTime.utc_now(),
		finished: Factory.bool(),
		note: Factory.uniq("note"),
		# in_scope_of_id:
		agreed_in: Factory.uniq("uri"),
		independent_demand_of_id: Factory.insert!(:plan).id,
		at_location_id: Factory.insert!(:spatial_thing).id,
		clause_of_id: Factory.insert!(:agreement).id,
	}}
end

describe "create Commitment" do
	test "with both :has_point_in_time and :has_beginning", %{params: params} do
		params = params
			|> Map.put(:has_point_in_time, DateTime.utc_now())
			|> Map.put(:has_beginning, DateTime.utc_now())

		assert {:error, %Changeset{errors: errs}} =
			params
			|> Commitment.chgset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :has_point_in_time)
		assert {:ok, _} = Keyword.fetch(errs, :has_beginning)
	end

	test "with both :has_point_in_time and :has_end", %{params: params} do
		params = params
			|> Map.put(:has_point_in_time, DateTime.utc_now())
			|> Map.put(:has_end, DateTime.utc_now())

		assert {:error, %Changeset{errors: errs}} =
			params
			|> Commitment.chgset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :has_point_in_time)
		assert {:ok, _} = Keyword.fetch(errs, :has_end)
	end

	test "with only :has_point_in_time", %{params: params} do
		params = Map.put(params, :has_point_in_time, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chgset()
			|> Repo.insert()

		assert comm.action_id == params.action_id
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert comm.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert comm.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert comm.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert comm.has_beginning == nil
		assert comm.has_end == nil
		assert comm.has_point_in_time == params.has_point_in_time
		assert comm.due == params.due
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with only :has_beginning", %{params: params} do
		params = Map.put(params, :has_beginning, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chgset()
			|> Repo.insert()

		assert comm.action_id == params.action_id
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert comm.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert comm.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert comm.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert comm.has_beginning == params.has_beginning
		assert comm.has_end == nil
		assert comm.has_point_in_time == nil
		assert comm.due == params.due
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with only :has_end", %{params: params} do
		params = Map.put(params, :has_end, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chgset()
			|> Repo.insert()

		assert comm.action_id == params.action_id
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert comm.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert comm.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert comm.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert comm.has_beginning == nil
		assert comm.has_end == params.has_end
		assert comm.has_point_in_time == nil
		assert comm.due == params.due
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with both :has_beginning and :has_end", %{params: params} do
		params = params
			|> Map.put(:has_beginning, DateTime.utc_now())
			|> Map.put(:has_end, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chgset()
			|> Repo.insert()

		assert comm.action_id == params.action_id
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert comm.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert comm.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert comm.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert comm.has_beginning == params.has_beginning
		assert comm.has_end == params.has_end
		assert comm.has_point_in_time == nil
		assert comm.due == params.due
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with both :resource_conforms_to and :resource_inventoried_as", %{params: params} do
		params = params
			|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
			|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:error, %Changeset{errors: errs}} =
			params
			|> Commitment.chgset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :resource_conforms_to_id)
		assert {:ok, _} = Keyword.fetch(errs, :resource_inventoried_as_id)
	end

	test "with only :resource_conforms_to", %{params: params} do
		params = params
			|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chgset()
			|> Repo.insert()

		assert comm.action_id == params.action_id
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == params.resource_conforms_to_id
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert comm.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert comm.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert comm.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert comm.has_beginning == nil
		assert comm.has_end == nil
		assert comm.has_point_in_time == params.has_point_in_time
		assert comm.due == params.due
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with only :resource_inventoried_as", %{params: params} do
		params = params
			|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chgset()
			|> Repo.insert()

		assert comm.action_id == params.action_id
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == params.resource_inventoried_as_id
		assert comm.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert comm.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert comm.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert comm.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert comm.has_beginning == nil
		assert comm.has_end == nil
		assert comm.has_point_in_time == params.has_point_in_time
		assert comm.due == params.due
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end
end

test "with present assocs", %{params: params} do
	old = Factory.insert!(:commitment)

	assert {:ok, %Commitment{} = new} =
		old
		|> Commitment.chgset(params)
		|> Repo.update()

	assert new.action_id == params.action_id
	assert new.provider_id == params.provider_id
	assert new.receiver_id == params.receiver_id
	assert new.input_of_id == params.input_of_id
	assert new.output_of_id == params.output_of_id
	assert new.resource_classified_as == params.resource_classified_as
	assert new.resource_conforms_to_id == old.resource_conforms_to_id
	assert new.resource_inventoried_as_id == old.resource_inventoried_as_id
	assert new.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert new.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert new.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert new.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	assert new.has_beginning == old.has_beginning
	assert new.has_end == old.has_end
	assert new.has_point_in_time == old.has_point_in_time
	assert new.due == params.due
	assert new.finished == params.finished
	assert new.note == params.note
	# assert in_scope_of_id
	assert new.agreed_in == params.agreed_in
	assert new.independent_demand_of_id == params.independent_demand_of_id
	assert new.at_location_id == params.at_location_id
	assert new.clause_of_id == params.clause_of_id
end
end
