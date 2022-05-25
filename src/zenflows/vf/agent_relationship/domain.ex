defmodule Zenflows.VF.AgentRelationship.Domain do
@moduledoc "Domain logic of AgentRelationships."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.AgentRelationship

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: AgentRelationship.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(AgentRelationship, id)
end

@spec create(params()) :: {:ok, AgentRelationship.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:rel, AgentRelationship.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{rel: rel}} -> {:ok, rel}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, AgentRelationship.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &AgentRelationship.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: rel}} -> {:ok, rel}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, AgentRelationship.t()} | {:error, chgset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: rel}} -> {:ok, rel}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(AgentRelationship.t(), :subject | :object | :relationship) :: AgentRelationship.t()
def preload(rel, :subject) do
	Repo.preload(rel, :subject)
end

def preload(rel, :object) do
	Repo.preload(rel, :object)
end

def preload(rel, :relationship) do
	Repo.preload(rel, :relationship)
end

# Returns an AgentRelationship in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, AgentRelationship.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			rel -> {:ok, rel}
		end
	end
end
end
