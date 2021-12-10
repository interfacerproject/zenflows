defmodule Zenflows.Valflow.Person.Domain do
@moduledoc "Domain logic of Persons."

import Ecto.Query

alias Ecto.Multi
alias Zenflows.Ecto.Repo
alias Zenflows.Valflow.Person

@typep repo() :: Ecto.Repo.t()
@typep chset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.Ecto.Schema.id()
@typep params() :: Zenflows.Ecto.Schema.params()

@spec by_id(repo(), id()) :: Person.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get_by(Person, id: id, type: :per)
end

@spec all() :: [Person.t()]
def all() do
	Person
	|> from()
	|> where(type: :per)
	|> Repo.all()
end

@spec create(params()) :: {:ok, Person.t()} | {:error, chset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:per, Person.chset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{per: p}} -> {:ok, p}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, Person.t()} | {:error, String.t() | chset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &Person.chset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: p}} -> {:ok, p}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, Person.t()} | {:error, String.t() | chset()}
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
