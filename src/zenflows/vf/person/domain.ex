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
alias Zenflows.DB.Repo
alias Zenflows.VF.Person

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by(repo(), Keyword.t() | map()) :: Person.t() | nil
def by(repo \\ Repo, clauses)
def by(repo, clauses) when is_map(clauses) do
	repo.get_by(Person, Map.put(clauses, :type, :per))
end
def by(repo, clauses) when is_list(clauses) do
	repo.get_by(Person, Keyword.put(clauses, :type, :per))
end

@spec by_id(repo(), id()) :: Person.t() | nil
def by_id(repo \\ Repo, id) do
	by(repo, id: id)
end

@spec by_user(repo(), String.t()) :: Person.t() | nil
def by_user(repo \\ Repo, user) do
	by(repo, user: user)
end

@spec exists_email(String.t()) :: boolean()
def exists_email(email) do
	where(Person, email: ^email) |> Repo.exists?()
end

@spec all() :: [Person.t()]
def all() do
	Person
	|> from()
	|> where(type: :per)
	|> Repo.all()
end

@spec create(params()) :: {:ok, Person.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:per, Person.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{per: p}} -> {:ok, p}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, Person.t()} | {:error, String.t() | chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &Person.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: p}} -> {:ok, p}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, Person.t()} | {:error, String.t() | chgset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: p}} -> {:ok, p}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(Person.t(), :primary_location) :: Person.t()
def preload(per, :primary_location) do
	Repo.preload(per, :primary_location)
end

# Returns a Person in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, Person.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			per -> {:ok, per}
		end
	end
end
end
