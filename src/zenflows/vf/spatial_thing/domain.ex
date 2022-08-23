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

defmodule Zenflows.VF.SpatialThing.Domain do
@moduledoc "Domain logic of SpatialThings."
# Basically, a fancy name for (geo)location.  :P

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.GQL.Paging
alias Zenflows.VF.SpatialThing

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id() | map() | Keyword.t())
	:: {:ok, SpatialThing.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(SpatialThing, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec all(Paging.params()) :: Paging.result(SpatialThing.t())
def all(params) do
	Paging.page(SpatialThing, params)
end

@spec create(params()) :: {:ok, SpatialThing.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:insert, SpatialThing.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{insert: st}} -> {:ok, st}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params())
	:: {:ok, SpatialThing.t()} | {:error, String.t() | chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.update(:update, &SpatialThing.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: st}} -> {:ok, st}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, SpatialThing.t()} | {:error, String.t() | chgset()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.delete(:delete, & &1.one)
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: st}} -> {:ok, st}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end
end
