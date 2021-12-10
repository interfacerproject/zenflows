defmodule Zenflows.Valflow.Unit.Domain do
@moduledoc "Domain logic of Units."

alias Ecto.Multi
alias Zenflows.Ecto.Repo
alias Zenflows.Valflow.Unit

@typep repo() :: Ecto.Repo.t()
@typep chset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.Ecto.Schema.id()
@typep params() :: Zenflows.Ecto.Schema.params()

@spec by_id(repo(), id()) :: Unit.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(Unit, id)
end

@spec create(params()) :: {:ok, Unit.t()} | {:error, chset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:unit, Unit.chset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{unit: u}} -> {:ok, u}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, Unit.t()} | {:error, chset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &Unit.chset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: u}} -> {:ok, u}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, Unit.t()} | {:error, chset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: u}} -> {:ok, u}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

# Returns a Unit in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, Unit.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			u -> {:ok, u}
		end
	end
end
end
