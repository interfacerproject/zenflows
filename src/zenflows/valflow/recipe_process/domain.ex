defmodule Zenflows.Valflow.RecipeProcess.Domain do
@moduledoc "Domain logic of RecipeProcesss."

alias Ecto.Multi
alias Zenflows.Ecto.Repo
alias Zenflows.Valflow.RecipeProcess

@typep repo() :: Ecto.Repo.t()
@typep chset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.Ecto.Schema.id()
@typep params() :: Zenflows.Ecto.Schema.params()

@spec by_id(repo(), id()) :: RecipeProcess.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(RecipeProcess, id)
end

@spec create(params()) :: {:ok, RecipeProcess.t()} | {:error, chset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:rec_proc, RecipeProcess.chset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{rec_proc: rp}} -> {:ok, rp}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, RecipeProcess.t()} | {:error, chset()}
def update(id, params) do
	preload_has_duration? = Map.has_key?(params, :has_duration)

	Multi.new()
	|> Multi.run(:get, fn repo, x ->
		with {:ok, rp} <- multi_get(id).(repo, x) do
			rp = if preload_has_duration?,
				do: preload(rp, :has_duration),
				else: rp

			{:ok, rp}
		end
	end)
	|> Multi.update(:update, fn %{get: rp} ->
		params =
			if preload_has_duration? and params.has_duration != nil and rp.has_duration_id != nil do
				has_dur = Map.put(params.has_duration, :id, rp.has_duration_id)
				Map.put(params, :has_duration, has_dur)
			else
				params
			end

		RecipeProcess.chset(rp, params)
	end)
	|> Repo.transaction()
	|> case do
		{:ok, %{update: rp}} -> {:ok, rp}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, RecipeProcess.t()} | {:error, chset()}
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
	Repo.preload(rec_proc, :has_duration)
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
