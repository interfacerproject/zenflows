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

defmodule ZenflowsTest.Authz.Organization do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query
import ZenflowsTest.Help.AbsinCase, only: [run!: 2]

alias Zenflows.Authz.{ExecutionContext, PermissionLog, Roles}
alias Zenflows.VF.{AgentRelationship, Organization}

setup do
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person)}
end

defp admin_ctx(),
	do: ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})

test "creator becomes admin, logged", %{alice: alice} do
	{:ok, org} = Organization.Domain.create(Factory.ctx(alice), %{name: Factory.str("org")})
	admin_role = Roles.id!(Repo, "org.admin")
	assert %AgentRelationship{in_scope_of_id: scope} =
		Repo.get_by!(AgentRelationship, subject_id: alice.id, object_id: org.id, relationship_id: admin_role)
	assert scope == org.id
	assert [%PermissionLog{reason: "organization creator"}] =
		Repo.all(from l in PermissionLog, where: l.action == "relationship.grant" and l.subject_id == ^alice.id)
end

test "admin may update; others may not", %{alice: alice, bob: bob} do
	{:ok, org} = Organization.Domain.create(Factory.ctx(alice), %{name: Factory.str("org")})
	assert {:ok, %Organization{name: "renamed"}} =
		Organization.Domain.update(Factory.ctx(alice), org.id, %{name: "renamed"})
	assert {:error, :forbidden} = Organization.Domain.update(Factory.ctx(bob), org.id, %{name: "x"})
	assert {:error, :forbidden} = Organization.Domain.delete(Factory.ctx(bob), org.id)
end

test "org with relationships cannot be deleted, even by its admin", %{alice: alice} do
	{:ok, org} = Organization.Domain.create(Factory.ctx(alice), %{name: Factory.str("org")})
	assert {:error, "agent has relationships; it cannot be deleted"} =
		Organization.Domain.delete(Factory.ctx(alice), org.id)
end

test "existing org without admin: forbidden until assigned", %{alice: alice} do
	org = Factory.insert!(:organization)
	assert {:error, :forbidden} = Organization.Domain.update(Factory.ctx(alice), org.id, %{name: "x"})

	assert {:ok, %AgentRelationship{}} =
		Organization.Domain.assign_admin(admin_ctx(), org.id, alice.id, "ticket #42")
	assert {:ok, _} = Organization.Domain.update(Factory.ctx(alice), org.id, %{name: "x"})
	assert [%PermissionLog{service: :admin_key, actor_id: nil, reason: "ticket #42"}] =
		Repo.all(from l in PermissionLog, where: l.action == "relationship.grant" and l.subject_id == ^alice.id)
end

test "assign_admin requires the admin key and a reason", %{alice: alice} do
	org = Factory.insert!(:organization)
	assert {:error, :forbidden} = Organization.Domain.assign_admin(Factory.ctx(alice), org.id, alice.id, "r")
	assert {:error, "reason is required"} = Organization.Domain.assign_admin(admin_ctx(), org.id, alice.id, " ")
end

test "assignOrganizationAdmin over GraphQL with the admin key", %{alice: alice} do
	org = Factory.insert!(:organization)
	key = Application.fetch_env!(:zenflows, Zenflows.Admin)[:admin_key] |> Base.encode16(case: :lower)
	assert %{data: %{"assignOrganizationAdmin" => %{"id" => _}}} =
		run!("""
			mutation ($org: ID!, $per: ID!) {
				assignOrganizationAdmin(organizationId: $org, personId: $per, reason: "ops") { id }
			}
		""", auth?: true, ctx: %{gql_admin: key}, vars: %{"org" => org.id, "per" => alice.id})
end
end
