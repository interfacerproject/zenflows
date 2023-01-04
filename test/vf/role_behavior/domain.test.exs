# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

defmodule ZenflowsTest.VF.RoleBehavior.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{RoleBehavior, RoleBehavior.Domain}

setup do
	%{
		params: %{
			name: Factory.str("name"),
			note: Factory.str("note"),
		},
		inserted: Factory.insert!(:role_behavior),
	}
end

describe "one/1" do
	test "with good id: finds the RoleBehavior", %{inserted: %{id: id}} do
		assert {:ok, %RoleBehavior{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the RoleBehavior" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a RoleBehavior", %{params: params} do
		assert {:ok, %RoleBehavior{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
	end

	test "with bad params: doesn't create a Process" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the Process", %{params: params, inserted: old} do
		assert {:ok, %RoleBehavior{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
	end

	test "with bad params: doesn't update the Process", %{inserted: old} do
		assert {:ok, %RoleBehavior{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.note == old.note
	end
end

describe "delete/1" do
	test "with good id: deletes the RoleBehavior", %{inserted: %{id: id}} do
		assert {:ok, %RoleBehavior{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the RoleBehavior" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end
end
