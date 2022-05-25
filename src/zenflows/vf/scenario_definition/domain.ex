defmodule Zenflows.VF.ScenarioDefinition.Domain do
@moduledoc "Domain logic of ScenarioDefinitions."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.{Duration, ScenarioDefinition}

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: ScenarioDefinition.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(ScenarioDefinition, id)
end

@spec create(params()) :: {:ok, ScenarioDefinition.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:scen_def, ScenarioDefinition.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{scen_def: sd}} -> {:ok, sd}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, ScenarioDefinition.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &ScenarioDefinition.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: sd}} -> {:ok, sd}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, ScenarioDefinition.t()} | {:error, chgset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: sd}} -> {:ok, sd}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(ScenarioDefinition.t(), :has_duration) :: ScenarioDefinition.t()
def preload(scen_def, :has_duration) do
	Duration.preload(scen_def, :has_duration)
end

# Returns a ScenarioDefinition in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id())
	:: (repo(), changes() -> {:ok, ScenarioDefinition.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			sd -> {:ok, sd}
		end
	end
end
end
