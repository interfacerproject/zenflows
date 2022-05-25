defmodule ZenflowsTest.VF.RecipeExchange.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{RecipeExchange, RecipeExchange.Domain}

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		recipe_exchange: Factory.insert!(:recipe_exchange),
	}
end

test "by_id/1 returns a RecipeExchange", %{recipe_exchange: rec_exch} do
	assert %RecipeExchange{} = Domain.by_id(rec_exch.id)
end

describe "create/1" do
	test "creates a RecipeExchange with valid params", %{params: params} do
		assert {:ok, %RecipeExchange{} = rec_exch} = Domain.create(params)

		assert rec_exch.name == params.name
		assert rec_exch.note == params.note
	end

	test "doesn't create a RecipeExchange with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a RecipeExchange with valid params", %{params: params, recipe_exchange: old} do
		assert {:ok, %RecipeExchange{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
	end

	test "doesn't update a RecipeExchange", %{recipe_exchange: old} do
		assert {:ok, %RecipeExchange{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
	end
end

test "delete/1 deletes a RecipeExchange", %{recipe_exchange: %{id: id}} do
	assert {:ok, %RecipeExchange{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
