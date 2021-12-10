defmodule ZenflowsTest.Valflow.RecipeFlow do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.RecipeFlow

setup do
	%{params: %{
		action: Factory.build(:action_enum),
		recipe_input_of_id: Factory.insert!(:recipe_process).id,
		recipe_output_of_id: Factory.insert!(:recipe_process).id,
		recipe_flow_resource_id: Factory.insert!(:recipe_resource).id,
		resource_quantity_id: Factory.insert!(:measure).id,
		effort_quantity_id: Factory.insert!(:measure).id,
		recipe_clause_of_id: Factory.insert!(:recipe_exchange).id,
		note: Factory.uniq("some note"),
	}}
end

test "create RecipeFlow", %{params: params} do
	assert {:ok, %RecipeFlow{} = rec_flow} =
		params
		|> RecipeFlow.chset()
		|> Repo.insert()

	assert rec_flow.action == params.action
	assert rec_flow.recipe_input_of_id == params.recipe_input_of_id
	assert rec_flow.recipe_output_of_id == params.recipe_output_of_id
	assert rec_flow.recipe_flow_resource_id == params.recipe_flow_resource_id
	assert rec_flow.resource_quantity_id == params.resource_quantity_id
	assert rec_flow.effort_quantity_id == params.effort_quantity_id
	assert rec_flow.recipe_clause_of_id == params.recipe_clause_of_id
	assert rec_flow.note == params.note
end

test "update RecipeFlow", %{params: params} do
	assert {:ok, %RecipeFlow{} = rec_flow} =
			:recipe_flow
			|> Factory.insert!()
			|> RecipeFlow.chset(params)
			|> Repo.update()

	assert rec_flow.action == params.action
	assert rec_flow.recipe_input_of_id == params.recipe_input_of_id
	assert rec_flow.recipe_output_of_id == params.recipe_output_of_id
	assert rec_flow.recipe_flow_resource_id == params.recipe_flow_resource_id
	assert rec_flow.resource_quantity_id == params.resource_quantity_id
	assert rec_flow.effort_quantity_id == params.effort_quantity_id
	assert rec_flow.recipe_clause_of_id == params.recipe_clause_of_id
	assert rec_flow.note == params.note
end
end
