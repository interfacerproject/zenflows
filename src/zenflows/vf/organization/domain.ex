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

defmodule Zenflows.VF.Organization.Domain do
@moduledoc "Domain logic of Organizations."

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, Membership}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.File
alias Zenflows.VF.{AgentRelationship, Organization, Organization.Query, Person}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, Organization.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	import Ecto.Query

	case repo.get_by(where(Organization, type: :org), clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: Organization.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [Organization.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	with {:ok, q} <- Query.all(page) do
		{:ok, Page.all(q, page)}
	end
end

@spec all!(Page.t()) :: [Organization.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec create(ExecutionContext.t(), Schema.params())
	:: {:ok, Organization.t()} | {:error, atom() | String.t() | Changeset.t()}
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

@spec create!(ExecutionContext.t(), Schema.params()) :: Organization.t()
def create!(ctx, params) do
	{:ok, value} = create(ctx, params)
	value
end

@spec update(ExecutionContext.t(), Schema.id(), Schema.params())
	:: {:ok, Organization.t()} | {:error, atom() | String.t() | Changeset.t()}
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

@spec update!(ExecutionContext.t(), Schema.id(), Schema.params()) :: Organization.t()
def update!(ctx, id, params) do
	{:ok, value} = update(ctx, id, params)
	value
end

@spec delete(ExecutionContext.t(), Schema.id())
	:: {:ok, Organization.t()} | {:error, atom() | String.t() | Changeset.t()}
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

@spec delete!(ExecutionContext.t(), Schema.id()) :: Organization.t()
def delete!(ctx, id) do
	{:ok, value} = delete(ctx, id)
	value
end

@doc """
Make `person_id` an admin of an existing organization.  Admin key
only; the reason is stored in the permission log.
"""
@spec assign_admin(ExecutionContext.t(), Schema.id(), Schema.id(), String.t())
	:: {:ok, AgentRelationship.t()} | {:error, term()}
def assign_admin(%ExecutionContext{} = ctx, org_id, person_id, reason) do
	Multi.new()
	|> Authz.multi_authorize(:authz, ctx, "organization.assign_admin",
		fn repo, _ -> Facts.for_organization(repo, ctx, org_id) end)
	|> Authz.multi_target(:org, :authz)
	|> Multi.run(:reason, fn _, _ ->
		if is_binary(reason) and String.trim(reason) != "",
			do: {:ok, reason},
			else: {:error, "reason is required"}
	end)
	|> Membership.multi_record_grant(:admin, ctx, %{
		subject_id: person_id,
		object_id: org_id,
		role_key: "org.admin",
		reason: reason,
	})
	|> Repo.transaction()
	|> case do
		{:ok, %{admin: rel}} -> {:ok, rel}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec preload(Organization.t(), :images | :primary_location) :: Organization.t()
def preload(org, x) when x in ~w[primary_location]a,
	do: Repo.preload(org, x)
def preload(org, :images),
	do: File.Domain.preload_gql(org, :images, :agent_id)

@spec multi_key() :: atom()
def multi_key(), do: :organization

@spec multi_insert(Multi.t(), ExecutionContext.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, ctx, key \\ multi_key(), params) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "organization.create", fn _, _ -> %Facts{} end)
	|> Multi.insert(key, Organization.changeset(params))
	|> File.Domain.multi_insert(key, :images, :agent_id)
	|> multi_bootstrap_admin(ctx, key)
end

@spec multi_update(Multi.t(), ExecutionContext.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, ctx, key \\ multi_key(), id, params) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "organization.update",
		fn repo, _ -> Facts.for_organization(repo, ctx, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.update(key,
		&Organization.changeset(Map.fetch!(&1, "#{key}.one"), params))
	|> File.Domain.multi_update(key, :images, :agent_id)
end

@spec multi_delete(Multi.t(), ExecutionContext.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, ctx, key \\ multi_key(), id) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "organization.delete",
		fn repo, _ -> Facts.for_organization(repo, ctx, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.run("#{key}.deletable", fn repo, _ -> Membership.check_deletable(repo, id) end)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end

# The creator of an organization becomes its first admin, within the
# same transaction (authorized by `organization.create`).
defp multi_bootstrap_admin(m, %ExecutionContext{principal: %Person{id: pid}} = ctx, key) do
	Membership.multi_record_grant(m, "#{key}.admin", ctx, fn changes ->
		%{
			subject_id: pid,
			object_id: Map.fetch!(changes, key).id,
			role_key: "org.admin",
			reason: "organization creator",
		}
	end)
end
defp multi_bootstrap_admin(m, _ctx, _key), do: m
end
