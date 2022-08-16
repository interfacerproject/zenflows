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

defmodule ZenflowsTest.VF.Intent.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Action,
	Agent,
	EconomicResource,
	Intent,
	Intent.Domain,
	Measure,
	Process,
	ResourceSpecification,
	SpatialThing,
}

setup do
	%{
		params: %{
			action_id: Factory.build(:action_id),
			input_of_id: Factory.insert!(:process).id,
			output_of_id: Factory.insert!(:process).id,
			provider_id: Factory.insert!(:agent).id,
			receiver_id: Factory.insert!(:agent).id,
			resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_classified_as: Factory.uniq_list("uri"),
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			effort_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			available_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_beginning: Factory.now(),
			has_end: Factory.now(),
			has_point_in_time: Factory.now(),
			due: Factory.now(),
			finished: Factory.bool(),
			at_location_id: Factory.insert!(:spatial_thing).id,
			image: Factory.img(),
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			# in_scope_of_id:
			agreed_in: Factory.uniq("uri"),
		},
		inserted: Factory.insert!(:intent),
		id: Factory.id(),
	}
end

describe "one/1" do
	test "with good id: finds the Intent", %{inserted: %{id: id}} do
		assert {:ok, %Intent{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the Intent", %{id: id} do
		assert {:error, "not found"} = Domain.one(id)
	end
end

describe "create/1" do
	test "with good params (with only :provider): creates an Intent", %{params: params} do
		params = Map.put(params, :receiver_id, nil)
		assert {:ok, %Intent{} = int} = Domain.create(params)

		keys = ~w[
			action_id
			provider_id receiver_id
			input_of_id output_of_id
			resource_inventoried_as_id resource_conforms_to_id resource_classified_as
			has_beginning has_end has_point_in_time due
			finished image name note agreed_in at_location_id
		]a # in_scope_of_id
		assert Map.take(int, keys) == Map.take(params, keys)

		assert int.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert int.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert int.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert int.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert int.available_quantity_has_unit_id == params.available_quantity.has_unit_id
		assert int.available_quantity_has_numerical_value == params.available_quantity.has_numerical_value
	end

	test "with good params (with only :receiver): creates an Intent", %{params: params} do
		params = Map.put(params, :provider_id, nil)
		assert {:ok, %Intent{} = int} = Domain.create(params)

		keys = ~w[
			action_id
			provider_id receiver_id
			input_of_id output_of_id
			resource_inventoried_as_id resource_conforms_to_id resource_classified_as
			has_beginning has_end has_point_in_time due
			finished image name note agreed_in at_location_id
		]a # in_scope_of_id
		assert Map.take(int, keys) == Map.take(params, keys)

		assert int.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert int.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert int.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert int.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert int.available_quantity_has_unit_id == params.available_quantity.has_unit_id
		assert int.available_quantity_has_numerical_value == params.available_quantity.has_numerical_value
	end

	test "with bad params (with both :provider and :receiver): doesn't create an Intent", %{params: params} do
		assert {:error, %Changeset{errors: errs}} = Domain.create(params)
		assert {:ok, _} = Keyword.fetch(errs, :provider_id)
		assert {:ok, _} = Keyword.fetch(errs, :receiver_id)
	end

	test "with bad params: doesn't create an Intent" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params (with only :provider): updates the Intent", %{params: params} do
		params = Map.put(params, :receiver_id, nil)
		old = Factory.insert!(:intent, %{receiver: nil, provider: Factory.build(:agent)})
		assert {:ok, %Intent{} = new} = Domain.update(old.id, params)

		keys = ~w[
			action_id
			provider_id receiver_id
			input_of_id output_of_id
			resource_inventoried_as_id resource_conforms_to_id resource_classified_as
			has_beginning has_end has_point_in_time due
			finished image name note agreed_in at_location_id
		]a # in_scope_of_id
		assert Map.take(new, keys) == Map.take(params, keys)

		assert new.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert new.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert new.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert new.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert new.available_quantity_has_unit_id == params.available_quantity.has_unit_id
		assert new.available_quantity_has_numerical_value == params.available_quantity.has_numerical_value
	end

	test "with good params (with only :receiver): updates the Intent", %{params: params} do
		params = Map.put(params, :provider_id, nil)
		old = Factory.insert!(:intent, %{provider: nil, receiver: Factory.build(:agent)})
		assert {:ok, %Intent{} = new} = Domain.update(old.id, params)

		keys = ~w[
			action_id
			provider_id receiver_id
			input_of_id output_of_id
			resource_inventoried_as_id resource_conforms_to_id resource_classified_as
			has_beginning has_end has_point_in_time due
			finished image name note agreed_in at_location_id
		]a # in_scope_of_id
		assert Map.take(new, keys) == Map.take(params, keys)

		assert new.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert new.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert new.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert new.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
		assert new.available_quantity_has_unit_id == params.available_quantity.has_unit_id
		assert new.available_quantity_has_numerical_value == params.available_quantity.has_numerical_value
	end

	test "with bad params (with both :provider and :receiver): updates the Intent", %{params: params} do
		int = Factory.insert!(:intent, %{provider: Factory.build(:agent), receiver: nil})
		assert {:error, %Changeset{errors: errs}} = Domain.update(int.id, params)

		assert {:ok, _} = Keyword.fetch(errs, :provider_id)
		assert {:ok, _} = Keyword.fetch(errs, :receiver_id)
	end

	test "with bad params (with both :receiver and :provider): updates the Intent", %{params: params} do
		int = Factory.insert!(:intent, %{provider: nil, receiver: Factory.build(:agent)})
		assert {:error, %Changeset{errors: errs}} = Domain.update(int.id, params)

		assert {:ok, _} = Keyword.fetch(errs, :provider_id)
		assert {:ok, _} = Keyword.fetch(errs, :receiver_id)
	end

	test "with bad params: doesn't update the Intent", %{inserted: old} do
		assert {:ok, %Intent{} = new} = Domain.update(old.id, %{})
		keys = ~w[
			action_id
			provider_id receiver_id
			input_of_id output_of_id
			resource_inventoried_as_id resource_conforms_to_id resource_classified_as
			resource_quantity_has_unit_id resource_quantity_has_numerical_value
			effort_quantity_has_unit_id effort_quantity_has_numerical_value
			available_quantity_has_unit_id available_quantity_has_numerical_value
			has_beginning has_end has_point_in_time due
			finished image name note agreed_in at_location_id
		]a # in_scope_of_id
		assert Map.take(new, keys) == Map.take(old, keys)
	end
end

describe "delete/1" do
	test "with good id: deletes the Intent", %{inserted: %{id: id}} do
		assert {:ok, %Intent{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the Intent", %{id: id} do
		assert {:error, "not found"} = Domain.delete(id)
	end
end

describe "preload/2" do
	test "preloads `:action`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :action)
		assert %Action{} = int.action
	end

	test "preloads `:input_of`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :input_of)
		assert %Process{} = int.input_of
	end

	test "preloads `:output_of`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :output_of)
		assert %Process{} = int.output_of
	end

	test "preloads `:provider`" do
		%{id: id} =
			Factory.insert!(:intent, %{provider: Factory.build(:agent), receiver: nil})

		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :provider)
		assert %Agent{} = int.provider
	end

	test "preloads `:receiver`" do
		%{id: id} =
			Factory.insert!(:intent, %{provider: nil, receiver: Factory.build(:agent)})

		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :receiver)
		assert %Agent{} = int.receiver
	end

	test "preloads `:resource_inventoried_as`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :resource_inventoried_as)
		assert %EconomicResource{} = int.resource_inventoried_as
	end

	test "preloads `:resource_conforms_to`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :resource_conforms_to)
		assert %ResourceSpecification{} = int.resource_conforms_to
	end

	test "preloads `:resource_quantity`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :resource_quantity)
		assert %Measure{} = int.resource_quantity
	end

	test "preloads `:effort_quantity`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :effort_quantity)
		assert %Measure{} = int.effort_quantity
	end

	test "preloads `:available_quantity`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :available_quantity)
		assert %Measure{} = int.available_quantity
	end

	test "preloads `:at_location`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)
		int = Domain.preload(int, :at_location)
		assert %SpatialThing{} = int.at_location
	end

	test "preloads `:published_in`", %{inserted: %{id: id}} do
		assert {:ok, int} =  Domain.one(id)

		assert [] = Domain.preload(int, :published_in).published_in

		left =
			Enum.map(0..9, fn _ ->
				Factory.insert!(:proposed_intent, %{publishes: int}).id
			end)
		right =
			Domain.preload(int, :published_in)
			|> Map.fetch!(:published_in)
			|> Enum.map(& &1.id)
		assert left -- right == []
	end
end
end
