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

defmodule Zenflows.Authz.Membership do
@moduledoc """
Organization roles as ValueFlows AgentRelationships with a system
AgentRelationshipRole (`org.admin`, `org.member`), scoped to the
organization through `in_scope_of`.  Every grant and revocation writes a
permission log entry; system-role relationships are revoked, never
deleted.
"""

import Ecto.Query

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, Log, ResourceControl, Roles}
alias Zenflows.VF.{AgentRelationship, Organization, Person}

@type grant() :: %{
	required(:subject_id) => String.t(),
	required(:object_id) => String.t(),
	required(:role_key) => String.t(),
	optional(:note) => nil | String.t(),
	optional(:reason) => nil | String.t(),
}

@doc "Authorize `relationship.grant`, then record the grant."
@spec multi_grant(Multi.t(), term(), ExecutionContext.t(), grant()) :: Multi.t()
def multi_grant(m, key, ctx, grant) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.grant", fn repo, _ ->
		# Same lock order as multi_revoke/5: the organization's advisory
		# lock first, then the actor's admin row FOR SHARE.
		if is_binary(grant.object_id), do: :ok = lock_org(repo, grant.object_id)
		%Facts{
			target: grant,
			role_key: grant.role_key,
			admin_of: Facts.admin_of(repo, ctx, [grant.object_id]),
		}
	end)
	|> multi_record_grant(key, ctx, grant)
end

@doc """
Record a grant WITHOUT authorizing it.  Only for callers that already
authorized an action implying the grant (`organization.create`,
`organization.assign_admin`); see the allowlist in
test/authz/guard.test.exs.
"""
@spec multi_record_grant(Multi.t(), term(), ExecutionContext.t(), grant() | (map() -> grant()))
	:: Multi.t()
def multi_record_grant(m, key, ctx, grant_or_fun) do
	m
	|> Multi.run(key, fn repo, changes ->
		grant = resolve(grant_or_fun, changes)
		with :ok <- lock_org(repo, grant.object_id),
				:ok <- validate_grant(repo, grant),
				role_id = Roles.id!(repo, grant.role_key),
				:ok <- not_already_granted(repo, grant, role_id) do
			%AgentRelationship{}
			|> AgentRelationship.system_changeset(%{
				subject_id: grant.subject_id,
				object_id: grant.object_id,
				relationship_id: role_id,
				in_scope_of_id: grant.object_id,
				note: Map.get(grant, :note),
			})
			|> repo.insert()
		end
	end)
	|> Log.multi_insert("#{key}.log", ctx, fn changes ->
		grant = resolve(grant_or_fun, changes)
		rel = Map.fetch!(changes, key)
		%{
			action: "relationship.grant",
			target_type: "agent_relationship",
			target_id: rel.id,
			subject_id: rel.subject_id,
			role_key: grant.role_key,
			after: %{object_id: rel.object_id},
			reason: Map.get(grant, :reason),
		}
	end)
end

@doc "Authorize `relationship.revoke`, then set `revoked_at` and log."
@spec multi_revoke(Multi.t(), term(), ExecutionContext.t(), AgentRelationship.t(), String.t())
	:: Multi.t()
def multi_revoke(m, key, ctx, %AgentRelationship{} = rel, role_key) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.revoke", fn repo, _ ->
		:ok = lock_org(repo, rel.object_id)
		%Facts{
			target: rel,
			role_key: role_key,
			admin_of: Facts.admin_of(repo, ctx, [rel.object_id]),
			active_admin_count: active_admin_count(repo, rel),
		}
	end)
	|> Multi.run(key, fn repo, _ ->
		if rel.revoked_at do
			{:error, "already revoked"}
		else
			rel |> Changeset.change(revoked_at: DateTime.utc_now()) |> repo.update()
		end
	end)
	|> Log.multi_insert("#{key}.log", ctx, fn changes ->
		revoked = Map.fetch!(changes, key)
		%{
			action: "relationship.revoke",
			target_type: "agent_relationship",
			target_id: revoked.id,
			subject_id: revoked.subject_id,
			role_key: role_key,
			before: %{revoked_at: nil},
			after: %{revoked_at: revoked.revoked_at},
		}
	end)
end

@doc "An agent with control or relationships cannot be hard-deleted."
@spec check_deletable(Ecto.Repo.t(), String.t()) :: {:ok, nil} | {:error, String.t()}
def check_deletable(repo, agent_id) do
	cond do
		repo.exists?(from c in ResourceControl, where: c.controller_id == ^agent_id) ->
			{:error, "agent controls resources; it cannot be deleted"}
		repo.exists?(from r in AgentRelationship,
				where: r.subject_id == ^agent_id or r.object_id == ^agent_id
					or r.in_scope_of_id == ^agent_id) ->
			{:error, "agent has relationships; it cannot be deleted"}
		true ->
			{:ok, nil}
	end
end

defp resolve(fun, changes) when is_function(fun, 1), do: fun.(changes)
defp resolve(grant, _changes), do: grant

@doc """
Serializes grants/revokes/system-relationship updates of one organization
(last-admin and duplicate checks).  Take this lock before locking any
relationship row of that organization, to keep lock ordering consistent
across concurrent transactions and avoid deadlocks (see
`Zenflows.VF.AgentRelationship.Domain.multi_load/3`).  Re-entrant within a
transaction: calling it more than once for the same org in the same
transaction is harmless.
"""
@spec lock_org(Ecto.Repo.t(), String.t()) :: :ok
def lock_org(repo, org_id) do
	repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", ["zf_org:" <> org_id])
	:ok
end

defp validate_grant(repo, grant) do
	cond do
		grant.role_key not in Roles.keys() ->
			{:error, "unknown system role"}
		not repo.exists?(from o in Organization, where: o.id == ^grant.object_id and o.type == :org) ->
			{:error, "object must be an organization"}
		not repo.exists?(from p in Person, where: p.id == ^grant.subject_id and p.type == :per) ->
			{:error, "subject must be a person"}
		true ->
			:ok
	end
end

defp not_already_granted(repo, grant, role_id) do
	if repo.exists?(from r in AgentRelationship,
			where: r.subject_id == ^grant.subject_id and r.object_id == ^grant.object_id
				and r.relationship_id == ^role_id and is_nil(r.revoked_at)),
		do: {:error, "already granted"},
		else: :ok
end

# Counts active `org.admin` relationships for the organization, treating
# `rel` itself as active regardless of its current `revoked_at` (it may
# already be revoked, e.g. on a repeated revoke of the same row).  This
# keeps the last-admin check describing the pre-revoke state, so a
# repeated revoke of an already-revoked row is authorized and then
# rejected by the idempotency check in `multi_revoke/5`, instead of
# being misread as "the last admin".
defp active_admin_count(repo, %AgentRelationship{} = rel) do
	admin_role = Roles.id!(repo, "org.admin")
	repo.aggregate(from(r in AgentRelationship,
		where: r.object_id == ^rel.object_id and r.relationship_id == ^admin_role
			and (is_nil(r.revoked_at) or r.id == ^rel.id)), :count)
end
end
