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

defmodule ZenflowsTest.Authz.Membership do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Zenflows.Authz.{PermissionLog, Roles}
alias Zenflows.VF.{AgentRelationship, AgentRelationshipRole}

setup do
	alice = Factory.insert!(:person)
	org = Factory.insert!(:organization)
	alice_rel = Factory.insert_admin!(alice, org)
	%{
		alice: alice, org: org, alice_rel: alice_rel,
		bob: Factory.insert!(:person),
		carol: Factory.insert!(:person),
		admin_role: Roles.id!(Repo, "org.admin"),
	}
end

defp grant(ctx, subject, c, params \\ %{}) do
	AgentRelationship.Domain.create(ctx, Map.merge(%{
		subject_id: subject.id, object_id: c.org.id, relationship_id: c.admin_role,
	}, params))
end

defp log_rows(action), do: Repo.all(from l in PermissionLog, where: l.action == ^action)

test "admin grants: scoped relationship and a log row", c do
	assert {:ok, %AgentRelationship{} = rel} = grant(Factory.ctx(c.alice), c.carol, c)
	assert rel.in_scope_of_id == c.org.id
	assert [%PermissionLog{actor_id: actor, subject_id: subject, role_key: "org.admin", target_id: tid}] =
		log_rows("relationship.grant")
	assert {actor, subject, tid} == {c.alice.id, c.carol.id, rel.id}
end

test "grant with string keys still goes through the grant path", c do
	assert {:error, :forbidden} = AgentRelationship.Domain.create(Factory.ctx(c.bob), %{
		"subject_id" => c.bob.id, "object_id" => c.org.id, "relationship_id" => c.admin_role,
	})
end

test "non-admin cannot grant; nothing written", c do
	assert {:error, :forbidden} = grant(Factory.ctx(c.bob), c.bob, c)
	assert log_rows("relationship.grant") == []
end

test "grant object must be an organization", c do
	assert {:error, "object must be an organization"} =
		grant(Factory.ctx(), c.carol, c, %{object_id: c.bob.id})
end

test "duplicate active grant is rejected; re-grant after revoke works", c do
	{:ok, rel} = grant(Factory.ctx(c.alice), c.carol, c)
	assert {:error, "already granted"} = grant(Factory.ctx(c.alice), c.carol, c)
	{:ok, _} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), rel.id)
	assert {:ok, %AgentRelationship{}} = grant(Factory.ctx(c.alice), c.carol, c)
end

test "revoke keeps the row, sets revoked_at, logs", c do
	{:ok, rel} = grant(Factory.ctx(c.alice), c.carol, c)
	assert {:ok, %AgentRelationship{revoked_at: %DateTime{}}} =
		AgentRelationship.Domain.delete(Factory.ctx(c.alice), rel.id)
	assert Repo.get!(AgentRelationship, rel.id).revoked_at
	assert [%PermissionLog{role_key: "org.admin"}] = log_rows("relationship.revoke")
	assert {:error, "already revoked"} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), rel.id)
end

test "the last admin cannot be revoked", c do
	assert {:error, :forbidden} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), c.alice_rel.id)
end

test "non-admin cannot revoke", c do
	{:ok, rel} = grant(Factory.ctx(c.alice), c.carol, c)
	assert {:error, :forbidden} = AgentRelationship.Domain.delete(Factory.ctx(c.bob), rel.id)
end

test "revoked admin cannot grant", c do
	{:ok, carol_rel} = grant(Factory.ctx(c.alice), c.carol, c)
	{:ok, _} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), carol_rel.id)
	assert {:error, :forbidden} = grant(Factory.ctx(c.carol), c.bob, c)
end

test "system relationship: note editable by admin, structure immutable", c do
	assert {:ok, %{note: "hi"}} =
		AgentRelationship.Domain.update(Factory.ctx(c.alice), c.alice_rel.id, %{note: "hi"})
	assert {:error, "system-role relationships can only change their note; revoke and grant instead"} =
		AgentRelationship.Domain.update(Factory.ctx(c.alice), c.alice_rel.id, %{subject_id: c.bob.id})
end

describe "non-system relationships" do
	setup c do
		role = Factory.insert!(:agent_relationship_role)
		%{role: role, bob_rel: AgentRelationship.Domain.create!(Factory.ctx(c.bob),
			%{subject_id: c.bob.id, object_id: c.carol.id, relationship_id: role.id})}
	end

	test "subject may create; others may not", c do
		assert {:error, :forbidden} = AgentRelationship.Domain.create(Factory.ctx(c.bob),
			%{subject_id: c.alice.id, object_id: c.carol.id, relationship_id: c.role.id})
	end

	test "others cannot update or delete", c do
		assert {:error, :forbidden} = AgentRelationship.Domain.update(Factory.ctx(c.alice), c.bob_rel.id, %{note: "x"})
		assert {:error, :forbidden} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), c.bob_rel.id)
	end

	test "cannot switch to a system role", c do
		assert {:error, "use a grant to assign a system role"} =
			AgentRelationship.Domain.update(Factory.ctx(c.bob), c.bob_rel.id, %{relationship_id: c.admin_role})
	end

	test "subject may delete (hard delete, no log)", c do
		assert {:ok, _} = AgentRelationship.Domain.delete(Factory.ctx(c.bob), c.bob_rel.id)
		assert Repo.get(AgentRelationship, c.bob_rel.id) == nil
	end
end

test "system roles are immutable, even for unchecked anonymous", c do
	assert {:error, :forbidden} =
		AgentRelationshipRole.Domain.update(Factory.ctx(), c.admin_role, %{role_label: "x"})
	assert {:error, :forbidden} = AgentRelationshipRole.Domain.delete(Factory.ctx(), c.admin_role)
	role = Factory.insert!(:agent_relationship_role)
	assert {:ok, %{role_label: "y"}} =
		AgentRelationshipRole.Domain.update(Factory.ctx(c.bob), role.id, %{role_label: "y"})
end
end
