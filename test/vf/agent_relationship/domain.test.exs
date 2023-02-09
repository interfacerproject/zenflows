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

defmodule ZenflowsTest.VF.AgentRelationship.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{AgentRelationship, AgentRelationship.Domain}

setup do
	%{
		params: %{
			subject_id: Factory.insert!(:agent).id,
			object_id: Factory.insert!(:agent).id,
			relationship_id: Factory.insert!(:agent_relationship_role).id,
			# in_scope_of:
			note: Factory.str("note"),
		},
		inserted: Factory.insert!(:agent_relationship),
	}
end

describe "one/1" do
	test "with good id: finds the AgentRelationship", %{inserted: %{id: id}} do
		assert {:ok, %AgentRelationship{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the AgentRelationship"do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates an AgentRelationship", %{params: params} do
		assert {:ok, %AgentRelationship{} = new} = Domain.create(params)
		assert new.subject_id == params.subject_id
		assert new.object_id == params.object_id
		assert new.relationship_id == params.relationship_id
		assert new.note == params.note
	end

	test "with bad params: doesn't create an AgentRelationship" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the AgentRelationship", %{params: params, inserted: old} do
		assert {:ok, %AgentRelationship{} = new} = Domain.update(old.id, params)
		assert new.subject_id == params.subject_id
		assert new.object_id == params.object_id
		assert new.relationship_id == params.relationship_id
		assert new.note == params.note
	end

	test "with bad params: doesn't update the AgentRelationship", %{inserted: old} do
		assert {:ok, %AgentRelationship{} = new} = Domain.update(old.id, %{})
		assert new.subject_id == old.subject_id
		assert new.object_id == old.object_id
		assert new.relationship_id == old.relationship_id
		assert new.note == old.note
	end
end

describe "delete/1" do
	test "with good id: deletes the AgentRelationship", %{inserted: %{id: id}} do
		assert {:ok, %AgentRelationship{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the AgentRelationship" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end
end
