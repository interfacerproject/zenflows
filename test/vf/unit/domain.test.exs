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

defmodule ZenflowsTest.VF.Unit.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Unit, Unit.Domain}

setup do
	%{
		params: %{
			label: Factory.str("label"),
			symbol: Factory.str("symbol"),
		},
		inserted: Factory.insert!(:unit),
	}
end

describe "one/1" do
	test "with good id: finds the Unit", %{inserted: %{id: id}} do
		assert {:ok, %Unit{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the Unit" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a Unit", %{params: params} do
		assert {:ok, %Unit{} = unit} = Domain.create(params)
		assert unit.label == params.label
		assert unit.symbol == params.symbol
	end

	test "with bad params: doesn't create a Unit" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the Unit", %{params: params, inserted: old} do
		assert {:ok, %Unit{} = new} = Domain.update(old.id, params)
		assert new.label == params.label
		assert new.symbol == params.symbol
	end

	test "with bad params: doesn't update the Unit", %{inserted: old} do
		assert {:ok, %Unit{} = new} = Domain.update(old.id, %{})
		assert new.label == old.label
		assert new.symbol == old.symbol
	end
end

describe "delete/1" do
	test "with good id: deletes the Unit", %{inserted: %{id: id}} do
		assert {:ok, %Unit{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the Unit" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end
end
