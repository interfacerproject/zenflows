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

defmodule Zenflows.VF.Person.Domain do
@moduledoc "Domain logic of Persons."

import Ecto.Query

alias Ecto.Multi
alias Zenflows.DB.{Paging, Repo}
alias Zenflows.VF.{Person, Person.Filter}

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id() | map() | Keyword.t()) :: {:ok, Person.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	clauses = if(is_map(clauses),
		do: Map.put(clauses, :type, :per),
		else: Keyword.put(clauses, :type, :per))
	case repo.get_by(Person, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec all(Paging.params()) :: Filter.error() | Paging.result()
def all(params \\ %{}) do
	with {:ok, q} <- Filter.filter(params[:filter] || %{}) do
		Paging.page(q, params)
	end
end

@spec exists?(Keyword.t()) :: boolean()
def exists?(conds) do
	where(Person, ^conds) |> Repo.exists?()
end

@spec pubkey(Keyword.t()) :: {:ok, Person.t()} | {:error, chgset()}
def pubkey(email) do
	where(Person, email: ^email)
	|> select([:eddsa_public_key]) |> Repo.one()
	|> case do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec create(params()) :: {:ok, Person.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:insert, Person.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{insert: p}} -> {:ok, p}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params())
	:: {:ok, Person.t()} | {:error, String.t() | chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.update(:update, &Person.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: p}} -> {:ok, p}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, Person.t()} | {:error, String.t() | chgset()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.delete(:delete, &(&1.one))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: p}} -> {:ok, p}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(Person.t(), :images | :primary_location) :: Person.t()
def preload(per, :images) do
	Repo.preload(per, :images)
end

def preload(per, :primary_location) do
	Repo.preload(per, :primary_location)
end
end
