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

defmodule Zenflows.VF.AgentRelationship.Domain do
@moduledoc "Domain logic of AgentRelationships."

require Ecto.Query

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, Membership, Roles}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.AgentRelationship

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, AgentRelationship.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(AgentRelationship, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: AgentRelationship.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [AgentRelationship.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	{:ok, Page.all(AgentRelationship, page)}
end

@spec all!(Page.t()) :: [AgentRelationship.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec create(ExecutionContext.t(), Schema.params())
	:: {:ok, AgentRelationship.t()} | {:error, atom() | String.t() | Changeset.t()}
def create(%ExecutionContext{} = ctx, params) do
	key = multi_key()
	Multi.new()
	|> multi_insert(ctx, params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec create!(ExecutionContext.t(), Schema.params()) :: AgentRelationship.t()
def create!(ctx, params) do
	{:ok, value} = create(ctx, params)
	value
end

@spec update(ExecutionContext.t(), Schema.id(), Schema.params())
	:: {:ok, AgentRelationship.t()} | {:error, atom() | String.t() | Changeset.t()}
def update(%ExecutionContext{} = ctx, id, params) do
	key = multi_key()
	Multi.new()
	|> multi_update(ctx, id, params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec update!(ExecutionContext.t(), Schema.id(), Schema.params()) :: AgentRelationship.t()
def update!(ctx, id, params) do
	{:ok, value} = update(ctx, id, params)
	value
end

@spec delete(ExecutionContext.t(), Schema.id())
	:: {:ok, AgentRelationship.t()} | {:error, atom() | String.t() | Changeset.t()}
def delete(%ExecutionContext{} = ctx, id) do
	key = multi_key()
	Multi.new()
	|> multi_delete(ctx, id)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec delete!(ExecutionContext.t(), Schema.id) :: AgentRelationship.t()
def delete!(ctx, id) do
	{:ok, value} = delete(ctx, id)
	value
end

@spec preload(AgentRelationship.t(), :subject | :object | :relationship | :in_scope_of)
	:: AgentRelationship.t()
def preload(rel, x) when x in ~w[subject object relationship in_scope_of]a do
	Repo.preload(rel, x)
end

@spec multi_key() :: atom()
def multi_key(), do: :agent_relationship

@spec multi_insert(Multi.t(), ExecutionContext.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, ctx, key \\ multi_key(), params) do
	m
	|> Multi.run("#{key}.role_key", fn repo, _ ->
		{:ok, Roles.key_of(repo, param(params, :relationship_id))}
	end)
	|> Multi.merge(fn changes ->
		case Map.fetch!(changes, "#{key}.role_key") do
			nil ->
				Multi.new()
				|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.create", fn repo, _ ->
					%Facts{target: %{subject_id: param(params, :subject_id)}, admin_of: Facts.admin_of(repo, ctx)}
				end)
				|> Multi.insert(key, AgentRelationship.changeset(params))
			role_key ->
				Membership.multi_grant(Multi.new(), key, ctx, %{
					subject_id: param(params, :subject_id),
					object_id: param(params, :object_id),
					role_key: role_key,
					note: param(params, :note),
				})
		end
	end)
end

@spec multi_update(Multi.t(), ExecutionContext.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, ctx, key \\ multi_key(), id, params) do
	m
	|> multi_load(key, id)
	|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.update", fn repo, changes ->
		%Facts{
			target: Map.fetch!(changes, "#{key}.one"),
			role_key: Map.fetch!(changes, "#{key}.role_key"),
			new_subject_id: param(params, :subject_id),
			admin_of: Facts.admin_of(repo, ctx),
		}
	end)
	|> Authz.multi_target("#{key}.target", "#{key}.authz")
	|> Multi.run("#{key}.checks", fn repo, changes ->
		validate_update(repo, Map.fetch!(changes, "#{key}.role_key"),
			Map.fetch!(changes, "#{key}.target"), params)
	end)
	|> Multi.update(key,
		&AgentRelationship.changeset(Map.fetch!(&1, "#{key}.target"), params))
end

@spec multi_delete(Multi.t(), ExecutionContext.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, ctx, key \\ multi_key(), id) do
	m
	|> multi_load(key, id)
	|> Multi.merge(fn changes ->
		rel = Map.fetch!(changes, "#{key}.one")
		case Map.fetch!(changes, "#{key}.role_key") do
			role_key when rel != nil and role_key != nil ->
				Membership.multi_revoke(Multi.new(), key, ctx, rel, role_key)
			_ ->
				Multi.new()
				|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.delete", fn repo, _ ->
					%Facts{target: rel, admin_of: Facts.admin_of(repo, ctx)}
				end)
				|> Authz.multi_target("#{key}.target", "#{key}.authz")
				|> Multi.delete(key, &Map.fetch!(&1, "#{key}.target"))
		end
	end)
end

defp multi_load(m, key, id) do
	m
	# Peek at the row WITHOUT locking it, just to tell whether it is a
	# system-role relationship.  If it is, take the organization's
	# advisory lock (Membership.lock_org/2) BEFORE locking the row itself,
	# so every transaction that may touch this org's system relationships
	# acquires locks in the same order: advisory lock first, row lock
	# second.  Taking them in the opposite order (row first, then the
	# advisory lock, as Membership.multi_grant/multi_revoke's own
	# authorize step used to do implicitly) lets two concurrent
	# revokes/updates of two different rows in the same org each hold one
	# row lock while waiting on the other's, deadlocking (Postgres
	# 40P01). Non-system rows never contend on the org lock, so they skip
	# straight to the row lock as before.
	|> Multi.run("#{key}.peek", fn repo, _ ->
		peek = repo.one(Ecto.Query.from(r in AgentRelationship,
			where: r.id == ^id,
			select: %{object_id: r.object_id, relationship_id: r.relationship_id}))
		case peek do
			nil ->
				{:ok, nil}
			%{object_id: object_id, relationship_id: relationship_id} ->
				if Roles.key_of(repo, relationship_id) != nil,
					do: Membership.lock_org(repo, object_id)
				{:ok, nil}
		end
	end)
	|> Multi.run("#{key}.one", fn repo, _ ->
		{:ok, repo.one(Ecto.Query.from(r in AgentRelationship, where: r.id == ^id, lock: "FOR UPDATE"))}
	end)
	|> Multi.run("#{key}.role_key", fn repo, changes ->
		case Map.fetch!(changes, "#{key}.one") do
			nil -> {:ok, nil}
			rel -> {:ok, Roles.key_of(repo, rel.relationship_id)}
		end
	end)
end

@system_immutable ~w[subject_id object_id relationship_id]a

defp validate_update(repo, role_key, rel, params) do
	cond do
		role_key != nil and Enum.any?(@system_immutable, fn f ->
				v = param(params, f)
				v != nil and v != Map.fetch!(rel, f)
			end) ->
			{:error, "system-role relationships can only change their note; revoke and grant instead"}
		role_key == nil and Roles.key_of(repo, param(params, :relationship_id)) != nil ->
			{:error, "use a grant to assign a system role"}
		true ->
			{:ok, nil}
	end
end

defp param(params, key), do: Map.get(params, key, Map.get(params, Atom.to_string(key)))
end
