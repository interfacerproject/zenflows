defmodule Zenflows.VF.Plan.Domain do
@moduledoc "Domain logic of Plans."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.Plan

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: Plan.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(Plan, id)
end

@spec create(params()) :: {:ok, Plan.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:plan, Plan.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{plan: p}} -> {:ok, p}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, Plan.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &Plan.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: p}} -> {:ok, p}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, Plan.t()} | {:error, chgset()}
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

@spec preload(Plan.t(), :refinement_of) :: Plan.t()
def preload(plan, :refinement_of) do
	Repo.preload(plan, :refinement_of)
end

# Returns a Plan in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id())
	:: (repo(), changes() -> {:ok, Plan.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			p -> {:ok, p}
		end
	end
end
end
