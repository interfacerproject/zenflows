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

defmodule ZenflowsTest.VF.Unit.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Unit, Unit.Domain}

setup do
	%{
		params: %{
			label: Factory.uniq("label"),
			symbol: Factory.uniq("symbol"),
		},
		unit: Factory.insert!(:unit),
	}
end

test "by_id/1 returns a Unit", %{unit: unit} do
	assert %Unit{} = Domain.by_id(unit.id)
end

describe "create/1" do
	test "creates a Unit with valid params", %{params: params} do
		assert {:ok, %Unit{} = unit} = Domain.create(params)

		assert unit.label == params.label
		assert unit.symbol == params.symbol
	end

	test "doesn't create a Unit with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a Unit with valid params", %{params: params, unit: old} do
		assert {:ok, %Unit{} = new} = Domain.update(old.id, params)

		assert new.label == params.label
		assert new.symbol == params.symbol
	end

	test "doesn't update a Unit", %{unit: old} do
		assert {:ok, %Unit{} = new} = Domain.update(old.id, %{})

		assert new.label == old.label
		assert new.symbol == old.symbol
	end
end

test "delete/1 deletes a Unit", %{unit: %{id: id}} do
	assert {:ok, %Unit{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
