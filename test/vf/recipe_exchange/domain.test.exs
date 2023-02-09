# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
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
			name: Factory.str("name"),
			note: Factory.str("note"),
		},
		inserted: Factory.insert!(:recipe_exchange),
	}
end

describe "one/1" do
	test "with good id: finds the RecipeExchange", %{inserted: %{id: id}} do
		assert {:ok, %RecipeExchange{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the RecipeExchange" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a RecipeExchange", %{params: params} do
		assert {:ok, %RecipeExchange{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
	end

	test "with bad params: doesn't create a Process" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the RecipeExchange", %{params: params, inserted: old} do
		assert {:ok, %RecipeExchange{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
	end

	test "with bad params: doesn't update the RecipeExchange", %{inserted: old} do
		assert {:ok, %RecipeExchange{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.note == old.note
	end
end

describe "delete/1" do
	test "with good id: deletes the RecipeExchange", %{inserted: %{id: id}} do
		assert {:ok, %RecipeExchange{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the RecipeExchange" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end
end
