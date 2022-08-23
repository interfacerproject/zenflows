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

defmodule ZenflowsTest.VF.AgentRelationshipRole.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{AgentRelationshipRole, AgentRelationshipRole.Domain}

setup do
	%{
		params: %{
			role_behavior_id: Factory.insert!(:role_behavior).id,
			role_label: Factory.str("role label"),
			inverse_role_label: Factory.str("inverse role label"),
			note: Factory.str("note"),
		},
		inserted: Factory.insert!(:agent_relationship_role),
	}
end

describe "one/1" do
	test "with good id: finds the AgentRelationshipRole", %{inserted: %{id: id}} do
		assert {:ok, %AgentRelationshipRole{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the AgentRelationshiprole"do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates an AgentRelationshipRole", %{params: params} do
		assert {:ok, %AgentRelationshipRole{} = new} = Domain.create(params)

		assert new.role_behavior_id == params.role_behavior_id
		assert new.role_label == params.role_label
		assert new.inverse_role_label == params.inverse_role_label
		assert new.note == params.note
	end

	test "with bad params: doesn't create an AgentRelationshipRole" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the AgentRelationshipRole", %{params: params, inserted: old} do
		assert {:ok, %AgentRelationshipRole{} = new} = Domain.update(old.id, params)
		assert new.role_behavior_id == params.role_behavior_id
		assert new.role_label == params.role_label
		assert new.inverse_role_label == params.inverse_role_label
		assert new.note == params.note
	end

	test "with bad params: doesn't update the AgentRelationshipRole", %{inserted: old} do
		assert {:ok, %AgentRelationshipRole{} = new} = Domain.update(old.id, %{})
		assert new.role_behavior_id == old.role_behavior_id
		assert new.role_label == old.role_label
		assert new.inverse_role_label == old.inverse_role_label
		assert new.note == old.note
	end
end

describe "delete/1" do
	test "with good id: deletes the AgentRelationshipRole", %{inserted: %{id: id}} do
		assert {:ok, %AgentRelationshipRole{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the AgentRelationshipRole" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end
end
