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

setup ctx do
	params = %{
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
		note: Factory.uniq("some note"),
 	}

	if ctx[:no_insert] do
		%{params: params}
	else
		%{params: params, recipe_flow: Factory.insert!(:recipe_flow)}
	end
end

test "by_id/1 returns a RecipeFlow", %{recipe_flow: rec_flow} do
	assert %RecipeFlow{} = Domain.by_id(rec_flow.id)
end

describe "create/1" do
	@tag :no_insert
	test "creates a RecipeFlow with valid params without `:effort_quantity`", %{params: params} do
		params = Map.delete(params, :effort_quantity)

		assert {:ok, %RecipeFlow{} = rec_flow} = Domain.create(params)
		assert rec_flow.note == params.note
		assert rec_flow.action_id == params.action_id
		assert rec_flow.recipe_input_of_id == params.recipe_input_of_id
		assert rec_flow.recipe_output_of_id == params.recipe_output_of_id
		assert rec_flow.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert rec_flow.recipe_clause_of_id == params.recipe_clause_of_id
		assert rec_flow.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert rec_flow.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert rec_flow.effort_quantity_has_unit_id == nil
		assert rec_flow.effort_quantity_has_numerical_value == nil
	end

	@tag :no_insert
	test "creates a RecipeFlow with valid params without :resource_quantity", %{params: params} do
		params = Map.delete(params, :resource_quantity)

		assert {:ok, %RecipeFlow{} = rec_flow} = Domain.create(params)
		assert rec_flow.note == params.note
		assert rec_flow.action_id == params.action_id
		assert rec_flow.recipe_input_of_id == params.recipe_input_of_id
		assert rec_flow.recipe_output_of_id == params.recipe_output_of_id
		assert rec_flow.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert rec_flow.recipe_clause_of_id == params.recipe_clause_of_id
		assert rec_flow.resource_quantity_has_unit_id == nil
		assert rec_flow.resource_quantity_has_numerical_value == nil
		assert rec_flow.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert rec_flow.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	end

	@tag :no_insert
	test "creates a RecipeFlow with valid params", %{params: params} do
		assert {:ok, %RecipeFlow{} = rec_flow} = Domain.create(params)
		assert rec_flow.note == params.note
		assert rec_flow.action_id == params.action_id
		assert rec_flow.recipe_input_of_id == params.recipe_input_of_id
		assert rec_flow.recipe_output_of_id == params.recipe_output_of_id
		assert rec_flow.recipe_flow_resource_id == params.recipe_flow_resource_id
		assert rec_flow.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert rec_flow.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert rec_flow.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
		assert rec_flow.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	end

	@tag :no_insert
	test "doesn't create a RecipeFlow with valid params without `:resource_quantity` and `:effort_quantity`", %{params: params} do
		params =
			params
			|> Map.delete(:resource_quantity)
			|> Map.delete(:effort_quantity)

		assert {:error, %Changeset{errors: errs}} = Domain.create(params)
		assert Keyword.has_key?(errs, :resource_quantity)
		assert Keyword.has_key?(errs, :effort_quantity)
	end

	test "doesn't create a RecipeFlow with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "doesn't update a RecipeFlow", %{recipe_flow: old} do
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

	test "doesn't update a RecipeFlow with valid params with `:resource_quantity` and `:effort_quantity` set to nil", %{params: params, recipe_flow: old} do
		params =
			params
			|> Map.put(:resource_quantity, nil)
			|> Map.put(:effort_quantity, nil)

		assert {:error, %Changeset{}} = Domain.update(old.id, params)
	end

	test "updates a RecipeFlow with valid params without `:effort_quantity`", %{params: params, recipe_flow: old} do
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

	test "updates a RecipeFlow with valid params without `:resource_quantity`", %{params: params, recipe_flow: old} do
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

	test "updates a RecipeFlow with valid params with a new `:resource_quantity` set to `nil`", %{params: params, recipe_flow: old} do
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

	test "updates a RecipeFlow with valid params with a new `:effort_quantity` set to `nil`", %{params: params, recipe_flow: old} do
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
end

test "delete/1 deletes a RecipeFlow", %{recipe_flow: %{id: id}} do
	assert {:ok, %RecipeFlow{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end

describe "preload/2" do
	test "preloads :resource_quantity", %{recipe_flow: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :resource_quantity)
		assert res_qty = %Measure{} = rec_flow.resource_quantity
		assert res_qty.has_unit_id == rec_flow.resource_quantity_has_unit_id
		assert res_qty.has_numerical_value == rec_flow.resource_quantity_has_numerical_value
	end

	test "preloads :effort_quantity", %{recipe_flow: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :effort_quantity)
		assert eff_qty = %Measure{} = rec_flow.effort_quantity
		assert eff_qty.has_unit_id == rec_flow.effort_quantity_has_unit_id
		assert eff_qty.has_numerical_value == rec_flow.effort_quantity_has_numerical_value
	end

	test "preloads :recipe_flow_resource", %{recipe_flow: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :recipe_flow_resource)
		assert rec_flow_res = %RecipeResource{} = rec_flow.recipe_flow_resource
		assert rec_flow_res.id == rec_flow.recipe_flow_resource_id
	end

	test "preloads :action", %{recipe_flow: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :action)
		assert action = %Action{} = rec_flow.action
		assert action.id == rec_flow.action_id
	end

	test "preloads :recipe_input_of", %{recipe_flow: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :recipe_input_of)
		assert rec_in_of = %RecipeProcess{} = rec_flow.recipe_input_of
		assert rec_in_of.id == rec_flow.recipe_input_of_id
	end

	test "preloads :recipe_output_of", %{recipe_flow: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :recipe_output_of)
		assert rec_out_of = %RecipeProcess{} = rec_flow.recipe_output_of
		assert rec_out_of.id == rec_flow.recipe_output_of_id
	end

	test "preloads :recipe_clause_of", %{recipe_flow: rec_flow} do
		rec_flow = Domain.preload(rec_flow, :recipe_clause_of)
		assert rec_clause_of = %RecipeExchange{} = rec_flow.recipe_clause_of
		assert rec_clause_of.id == rec_flow.recipe_clause_of_id
	end
end
end
