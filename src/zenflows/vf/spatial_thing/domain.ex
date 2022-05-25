defmodule Zenflows.VF.SpatialThing.Domain do
@moduledoc "Domain logic of SpatialThings."
# Basically, a fancy name for (geo)location.  :P

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.SpatialThing

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: SpatialThing.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(SpatialThing, id)
end

@spec create(params()) :: {:ok, SpatialThing.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:spt_thg, SpatialThing.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{spt_thg: st}} -> {:ok, st}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, SpatialThing.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &SpatialThing.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: st}} -> {:ok, st}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, SpatialThing.t()} | {:error, chgset()}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: st}} -> {:ok, st}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

# Returns a SpatialThing in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, SpatialThing.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			st -> {:ok, st}
		end
	end
end
end
