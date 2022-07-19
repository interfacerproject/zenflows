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

defmodule Zenflows.VF.AgentRelationship.Domain do
@moduledoc "Domain logic of AgentRelationships."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.AgentRelationship

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: AgentRelationship.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(AgentRelationship, id)
end

@spec create(params()) :: {:ok, AgentRelationship.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:rel, AgentRelationship.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{rel: rel}} -> {:ok, rel}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, AgentRelationship.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &AgentRelationship.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: rel}} -> {:ok, rel}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, AgentRelationship.t()} | {:error, chgset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: rel}} -> {:ok, rel}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(AgentRelationship.t(), :subject | :object | :relationship) :: AgentRelationship.t()
def preload(rel, :subject) do
	Repo.preload(rel, :subject)
end

def preload(rel, :object) do
	Repo.preload(rel, :object)
end

def preload(rel, :relationship) do
	Repo.preload(rel, :relationship)
end

# Returns an AgentRelationship in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, AgentRelationship.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			rel -> {:ok, rel}
		end
	end
end
end
