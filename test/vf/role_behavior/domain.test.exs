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

defmodule ZenflowsTest.VF.RoleBehavior.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{RoleBehavior, RoleBehavior.Domain}

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		role_behavior: Factory.insert!(:role_behavior),
	}
end

test "by_id/1 returns a RoleBehavior", %{role_behavior: role_beh} do
	assert %RoleBehavior{} = Domain.by_id(role_beh.id)
end

describe "create/1" do
	test "creates a RoleBehavior with valid params", %{params: params} do
		assert {:ok, %RoleBehavior{} = role_beh} = Domain.create(params)

		assert role_beh.name == params.name
		assert role_beh.note == params.note
	end

	test "doesn't create a RoleBehavior with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a RoleBehavior with valid params", %{params: params, role_behavior: old} do
		assert {:ok, %RoleBehavior{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
	end

	test "doesn't update a RoleBehavior", %{role_behavior: old} do
		assert {:ok, %RoleBehavior{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
	end
end

test "delete/1 deletes a RoleBehavior", %{role_behavior: %{id: id}} do
	assert {:ok, %RoleBehavior{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
