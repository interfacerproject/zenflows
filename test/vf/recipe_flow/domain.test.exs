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

defmodule ZenflowsTest.VF.RecipeFlow.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Action,
	Measure,
	RecipeExchange,
	RecipeFlow,
	RecipeFlow.Domain,
	RecipeProcess,
	RecipeResource,
}

setup do
	%{
		params: %{
			action_id: Factory.build(:action_id),
			recipe_input_of_id: Factory.insert!(:recipe_process).id,
			recipe_output_of_id: Factory.insert!(:recipe_process).id,
			recipe_flow_resource_id: Factory.insert!(:recipe_resource).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			effort_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			recipe_clause_of_id: Factory.insert!(:recipe_exchange).id,
			note: Factory.str("some note"),
	 	},
	 	inserted: Factory.insert!(:recipe_flow),
	 }
end

describe "one/1" do
	test "with good id: finds the RecipeFlow", %{inserted: %{id: id}} do
		assert {:ok, %RecipeFlow{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the RecipeFlow" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params (with :resource_quantity): creates a RecipeFlow", %{params: params} do
		params = Map.delete(params, :effort_quantity)
		assert {:ok, %RecipeFlow{} = new} = Domain.create(params)
		assert new.note == params.note
		assert new.action_id == params.action_id
		assert new.recipe_input_of_id == params.recipe_input_of_id
		assert new.recipe_output_of_id == params.recipe_output_of_id
		assert new.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert new.recipe_clause_of_id == params.recipe_clause_of_id
		assert new.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert new.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert new.effort_quantity_has_unit_id == nil
		assert new.effort_quantity_has_numerical_value == nil
	end

	test "with good params (with :effort_quantity): creates a RecipeFlow", %{params: params} do
		params = Map.delete(params, :resource_quantity)
		assert {:ok, %RecipeFlow{} = new} = Domain.create(params)
		assert new.note == params.note
		assert new.action_id == params.action_id
		assert new.recipe_input_of_id == params.recipe_input_of_id
		assert new.recipe_output_of_id == params.recipe_output_of_id
		assert new.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert new.recipe_clause_of_id == params.recipe_clause_of_id
		assert new.resource_quantity_has_unit_id == nil
		assert new.resource_quantity_has_numerical_value == nil
		assert new.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert new.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	end

	test "with good params (with :resource_quantity and :effort_quantity): creates a RecipeFlow", %{params: params} do
		assert {:ok, %RecipeFlow{} = new} = Domain.create(params)
		assert new.note == params.note
		assert new.action_id == params.action_id
		assert new.recipe_input_of_id == params.recipe_input_of_id
		assert new.recipe_output_of_id == params.recipe_output_of_id
		assert new.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert new.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert new.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert new.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert new.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	end

	test "with bad params (without :resource_qunatity and :effort_quantit): doesn't create a RecipeFlow", %{params: params} do
		params =
			params
			|> Map.delete(:resource_quantity)
			|> Map.delete(:effort_quantity)

		assert {:error, %Changeset{errors: errs}} = Domain.create(params)
		assert Keyword.has_key?(errs, :resource_quantity)
		assert Keyword.has_key?(errs, :effort_quantity)
	end

	test "with bad params: doesn't create a RecipeFlow" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params (with :resource_quantity): updates the RecipeFlow", %{params: params, inserted: old} do
		params = Map.delete(params, :effort_quantity)
		assert {:ok, %RecipeFlow{} = new} = Domain.update(old.id, params)
		assert new.note == params.note
		assert new.action_id == params.action_id
		assert new.recipe_input_of_id == params.recipe_input_of_id
		assert new.recipe_output_of_id == params.recipe_output_of_id
		assert new.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert new.recipe_clause_of_id == params.recipe_clause_of_id
		assert new.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert new.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert new.effort_quantity_has_unit_id == old.effort_quantity_has_unit_id
		assert new.effort_quantity_has_numerical_value == old.effort_quantity_has_numerical_value
	end

	test "with good params (with :effort_quantity): updates the RecipeFlow", %{params: params, inserted: old} do
		params = Map.delete(params, :resource_quantity)
		assert {:ok, %RecipeFlow{} = new} = Domain.update(old.id, params)
		assert new.note == params.note
		assert new.action_id == params.action_id
		assert new.recipe_input_of_id == params.recipe_input_of_id
		assert new.recipe_output_of_id == params.recipe_output_of_id
		assert new.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert new.recipe_clause_of_id == params.recipe_clause_of_id
		assert new.resource_quantity_has_unit_id == old.resource_quantity_has_unit_id
		assert new.resource_quantity_has_numerical_value == old.resource_quantity_has_numerical_value
		assert new.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert new.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	end

	test "with good params (with :resource_quantity set to nil): updates the RecipeFlow", %{params: params, inserted: old} do
		params =
			params
			|> Map.delete(:effort_quantity)
			|> Map.put(:resource_quantity, nil)

		assert {:ok, %RecipeFlow{} = new} = Domain.update(old.id, params)
		assert new.note == params.note
		assert new.action_id == params.action_id
		assert new.recipe_input_of_id == params.recipe_input_of_id
		assert new.recipe_output_of_id == params.recipe_output_of_id
		assert new.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert new.recipe_clause_of_id == params.recipe_clause_of_id
		assert new.resource_quantity_has_unit_id == nil
		assert new.resource_quantity_has_numerical_value == nil
		assert new.effort_quantity_has_unit_id == old.effort_quantity_has_unit_id
		assert new.effort_quantity_has_numerical_value == old.effort_quantity_has_numerical_value
	end

	test "with good params (with :effort_quantity set to nil): updates the RecipeFlow", %{params: params, inserted: old} do
		params =
			params
			|> Map.delete(:resource_quantity)
			|> Map.put(:effort_quantity, nil)

		assert {:ok, %RecipeFlow{} = new} = Domain.update(old.id, params)
		assert new.note == params.note
		assert new.action_id == params.action_id
		assert new.recipe_input_of_id == params.recipe_input_of_id
		assert new.recipe_output_of_id == params.recipe_output_of_id
		assert new.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert new.recipe_clause_of_id == params.recipe_clause_of_id
		assert new.resource_quantity_has_unit_id == old.resource_quantity_has_unit_id
		assert new.resource_quantity_has_numerical_value == old.resource_quantity_has_numerical_value
		assert new.effort_quantity_has_unit_id == nil
		assert new.effort_quantity_has_numerical_value == nil
	end

	test "with bad params: doesn't update the RecipeFlow", %{inserted: old} do
		assert {:ok, %RecipeFlow{} = new} = Domain.update(old.id, %{})
		assert new.note == old.note
		assert new.action_id == old.action_id
		assert new.recipe_input_of_id == old.recipe_input_of_id
		assert new.recipe_output_of_id == old.recipe_output_of_id
		assert new.recipe_flow_resource_id == old.recipe_flow_resource_id
		assert new.recipe_clause_of_id == old.recipe_clause_of_id
		assert new.resource_quantity_has_unit_id == old.resource_quantity_has_unit_id
		assert new.resource_quantity_has_numerical_value == old.resource_quantity_has_numerical_value
		assert new.effort_quantity_has_unit_id == old.effort_quantity_has_unit_id
		assert new.effort_quantity_has_numerical_value == old.effort_quantity_has_numerical_value
	end

	test "with bad params (with :resource_quantity and :effort_quantity set to nil): doesn't update the RecipeFlow", %{params: params, inserted: old} do
		params =
			params
			|> Map.put(:resource_quantity, nil)
			|> Map.put(:effort_quantity, nil)

		assert {:error, %Changeset{}} = Domain.update(old.id, params)
	end
end

describe "delete/1" do
	test "with good id: deletes the RecipeFlow", %{inserted: %{id: id}} do
		assert {:ok, %RecipeFlow{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the RecipeFlow" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end

describe "preload/2" do
	test "preloads :resource_quantity", %{inserted: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :resource_quantity)
		assert res_qty = %Measure{} = rec_flow.resource_quantity
		assert res_qty.has_unit_id == rec_flow.resource_quantity_has_unit_id
		assert res_qty.has_numerical_value == rec_flow.resource_quantity_has_numerical_value
	end

	test "preloads :effort_quantity", %{inserted: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :effort_quantity)
		assert eff_qty = %Measure{} = rec_flow.effort_quantity
		assert eff_qty.has_unit_id == rec_flow.effort_quantity_has_unit_id
		assert eff_qty.has_numerical_value == rec_flow.effort_quantity_has_numerical_value
	end

	test "preloads :recipe_flow_resource", %{inserted: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :recipe_flow_resource)
		assert rec_flow_res = %RecipeResource{} = rec_flow.recipe_flow_resource
		assert rec_flow_res.id == rec_flow.recipe_flow_resource_id
	end

	test "preloads :action", %{inserted: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :action)
		assert action = %Action{} = rec_flow.action
		assert action.id == rec_flow.action_id
	end

	test "preloads :recipe_input_of", %{inserted: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :recipe_input_of)
		assert rec_in_of = %RecipeProcess{} = rec_flow.recipe_input_of
		assert rec_in_of.id == rec_flow.recipe_input_of_id
	end

	test "preloads :recipe_output_of", %{inserted: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :recipe_output_of)
		assert rec_out_of = %RecipeProcess{} = rec_flow.recipe_output_of
		assert rec_out_of.id == rec_flow.recipe_output_of_id
	end

	test "preloads :recipe_clause_of", %{inserted: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :recipe_clause_of)
		assert rec_clause_of = %RecipeExchange{} = rec_flow.recipe_clause_of
		assert rec_clause_of.id == rec_flow.recipe_clause_of_id
	end
end
end
