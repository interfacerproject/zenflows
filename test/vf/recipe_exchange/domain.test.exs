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
