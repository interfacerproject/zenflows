defmodule ZenflowsTest.VF.RecipeResource.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	RecipeResource,
	RecipeResource.Domain,
	Unit,
}

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			resource_classified_as: Factory.uniq_list("uri"),
			unit_of_effort_id: Factory.insert!(:unit).id,
			unit_of_resource_id: Factory.insert!(:unit).id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			substitutable: Factory.bool(),
			note: Factory.uniq("note"),
			image: Factory.uri(),
		},
		recipe_resource: Factory.insert!(:recipe_resource),
	}
end

test "by_id/1 returns a RecipeResource", %{recipe_resource: rec_res} do
	assert %RecipeResource{} = Domain.by_id(rec_res.id)
end

describe "create/1" do
	test "creates a RecipeResource with valid params", %{params: params} do
		assert {:ok, %RecipeResource{} = rec_res} = Domain.create(params)

		assert rec_res.name == params.name
		assert rec_res.resource_classified_as == params.resource_classified_as
		assert rec_res.unit_of_resource_id == params.unit_of_resource_id
		assert rec_res.unit_of_effort_id == params.unit_of_effort_id
		assert rec_res.resource_conforms_to_id == params.resource_conforms_to_id
		assert rec_res.substitutable == params.substitutable
		assert rec_res.note == params.note
		assert rec_res.image == params.image
	end

	test "doesn't create a RecipeResource with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a RecipeResource with valid params", %{params: params, recipe_resource: old} do
		assert {:ok, %RecipeResource{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.resource_classified_as == params.resource_classified_as
		assert new.unit_of_resource_id == params.unit_of_resource_id
		assert new.unit_of_effort_id == params.unit_of_effort_id
		assert new.resource_conforms_to_id == params.resource_conforms_to_id
		assert new.substitutable == params.substitutable
		assert new.note == params.note
		assert new.image == params.image
	end

	test "doesn't update a RecipeResource", %{recipe_resource: old} do
		assert {:ok, %RecipeResource{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.resource_classified_as == old.resource_classified_as
		assert new.unit_of_resource_id == old.unit_of_resource_id
		assert new.unit_of_effort_id == old.unit_of_effort_id
		assert new.resource_conforms_to_id == old.resource_conforms_to_id
		assert new.substitutable == old.substitutable
		assert new.note == old.note
		assert new.image == nil # old.image
	end
end

test "delete/1 deletes a RecipeResource", %{recipe_resource: %{id: id}} do
	assert {:ok, %RecipeResource{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end

describe "preload/2" do
	test "preloads :unit_of_resource", %{recipe_resource: rec_res} do
		rec_res = Domain.preload(rec_res, :unit_of_resource)
		assert unit_res = %Unit{} = rec_res.unit_of_resource
		assert unit_res.id == rec_res.unit_of_resource_id
	end

	test "preloads :unit_of_effort", %{recipe_resource: rec_res} do
		rec_res = Domain.preload(rec_res, :unit_of_effort)
		assert unit_eff = %Unit{} = rec_res.unit_of_effort
		assert unit_eff.id == rec_res.unit_of_effort_id
	end
end
end
