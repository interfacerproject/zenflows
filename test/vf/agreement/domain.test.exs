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

defmodule ZenflowsTest.VF.Agreement.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Agreement, Agreement.Domain}

setup do
	%{
		params: %{
			name: Factory.str("name"),
			note: Factory.str("note"),
		},
		inserted: Factory.insert!(:agreement),
		id: Factory.id(),
	}
end

describe "one/1" do
	test "with good id: finds the Agreement", %{inserted: %{id: id}} do
		assert {:ok, %Agreement{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the Agreement", %{id: id} do
		assert {:error, "not found"} = Domain.one(id)
	end
end

describe "create/1" do
	test "with good params: creates an Agreement", %{params: params} do
		assert {:ok, %Agreement{} = agreem} = Domain.create(params)
		assert agreem.name == params.name
		assert agreem.note == params.note
	end

	test "with bad params: doesn't create an" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the Agreement", %{params: params, inserted: old} do
		assert {:ok, %Agreement{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
	end

	test "with bad params: doesn't update the Agreement", %{inserted: old} do
		assert {:ok, %Agreement{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.note == old.note
	end
end

describe "delete/1" do
	test "with good id: deletes the Agreement", %{inserted: %{id: id}} do
		assert {:ok, %Agreement{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the Agreement", %{id: id} do
		assert {:error, "not found"} = Domain.delete(id)
	end
end
end
