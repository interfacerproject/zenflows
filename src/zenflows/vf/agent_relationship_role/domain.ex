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

defmodule Zenflows.VF.AgentRelationshipRole.Domain do
@moduledoc "Domain logic of AgentRelationshipRoles."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.AgentRelationshipRole

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: AgentRelationshipRole.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(AgentRelationshipRole, id)
end

@spec create(params()) :: {:ok, AgentRelationshipRole.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:rel_role, AgentRelationshipRole.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{rel_role: rr}} -> {:ok, rr}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, AgentRelationshipRole.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &AgentRelationshipRole.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: rr}} -> {:ok, rr}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, AgentRelationshipRole.t()} | {:error, chgset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: rr}} -> {:ok, rr}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(AgentRelationshipRole.t(), :role_behavior) :: AgentRelationshipRole.t()
def preload(rel_role, :role_behavior) do
	Repo.preload(rel_role, :role_behavior)
end

# Returns an AgentRelationshipRole in ok-err tuple from given ID.
# Used inside Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, AgentRelationshipRole.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			rr -> {:ok, rr}
		end
	end
end
end
