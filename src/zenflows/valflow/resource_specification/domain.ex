defmodule Zenflows.Valflow.ResourceSpecification.Domain do
@moduledoc "Domain logic of ResourceSpecifications."

alias Ecto.Multi
alias Zenflows.Ecto.Repo
alias Zenflows.Valflow.ResourceSpecification

@typep repo() :: Ecto.Repo.t()
@typep chset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.Ecto.Schema.id()
@typep params() :: Zenflows.Ecto.Schema.params()

@spec by_id(repo(), id()) :: ResourceSpecification.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(ResourceSpecification, id)
end

@spec create(params()) :: {:ok, ResourceSpecification.t()} | {:error, chset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:res_spec, ResourceSpecification.chset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{res_spec: rs}} -> {:ok, rs}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, ResourceSpecification.t()} | {:error, chset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &ResourceSpecification.chset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: rs}} -> {:ok, rs}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, ResourceSpecification.t()} | {:error, chset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: rs}} -> {:ok, rs}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(ResourceSpecification.t(), :default_unit_of_resource | :default_unit_of_effort)
	:: ResourceSpecification.t()
def preload(res_spec, :default_unit_of_resource) do
	Repo.preload(res_spec, :default_unit_of_resource)
end

def preload(res_spec, :default_unit_of_effort) do
	Repo.preload(res_spec, :default_unit_of_effort)
end

# Returns a ResourceSpecification in ok-err tuple from given ID.
# Used inside Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, ResourceSpecification.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			rs -> {:ok, rs}
		end
	end
end
end
