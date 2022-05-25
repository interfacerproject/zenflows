defmodule Zenflows.VF.RecipeExchange.Domain do
@moduledoc "Domain logic of RecipeExchanges."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.RecipeExchange

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: RecipeExchange.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(RecipeExchange, id)
end

@spec create(params()) :: {:ok, RecipeExchange.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:rec_exch, RecipeExchange.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{rec_exch: re}} -> {:ok, re}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, RecipeExchange.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &RecipeExchange.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: re}} -> {:ok, re}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, RecipeExchange.t()} | {:error, chgset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: re}} -> {:ok, re}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

# Returns a RecipeExchange in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, RecipeExchange.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			re -> {:ok, re}
		end
	end
end
end
