defmodule Zenflows.VF.RecipeProcess.Domain do
@moduledoc "Domain logic of RecipeProcesss."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.{Duration, RecipeProcess}

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: RecipeProcess.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(RecipeProcess, id)
end

@spec create(params()) :: {:ok, RecipeProcess.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:rec_proc, RecipeProcess.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{rec_proc: rp}} -> {:ok, rp}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, RecipeProcess.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &RecipeProcess.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: rp}} -> {:ok, rp}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, RecipeProcess.t()} | {:error, chgset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: rp}} -> {:ok, rp}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(RecipeProcess.t(), :has_duration | :process_conforms_to)
	:: RecipeProcess.t()
def preload(rec_proc, :has_duration) do
	Duration.preload(rec_proc, :has_duration)
end

def preload(rec_proc, :process_conforms_to) do
	Repo.preload(rec_proc, :process_conforms_to)
end

# Returns a RecipeProcess in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, RecipeProcess.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			rp -> {:ok, rp}
		end
	end
end
end
