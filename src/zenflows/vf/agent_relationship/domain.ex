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
alias Zenflows.DB.{Paging, Repo}
alias Zenflows.VF.AgentRelationship

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id() | map() | Keyword.t())
	:: {:ok, AgentRelationship.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(AgentRelationship, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec all(Paging.params()) :: Paging.result()
def all(params) do
	Paging.page(AgentRelationship, params)
end

@spec create(params()) :: {:ok, AgentRelationship.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:insert, AgentRelationship.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{insert: ar}} -> {:ok, ar}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params())
	:: {:ok, AgentRelationship.t()} | {:error, String.t() | chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.update(:update, &AgentRelationship.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: ar}} -> {:ok, ar}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id())
	:: {:ok, AgentRelationship.t()} | {:error, String.t() | chgset()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.delete(:delete, &(&1.one))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: ar}} -> {:ok, ar}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(AgentRelationship.t(), :subject | :object | :relationship)
	:: AgentRelationship.t()
def preload(rel, :subject) do
	Repo.preload(rel, :subject)
end

def preload(rel, :object) do
	Repo.preload(rel, :object)
end

def preload(rel, :relationship) do
	Repo.preload(rel, :relationship)
end
end
