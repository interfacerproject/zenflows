# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.EconomicResource.Domain do
@moduledoc "Domain logic of EconomicResources."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.{
	Action,
	EconomicResource,
	Measure,
}

@typep repo() :: Ecto.Repo.t()
@typep error() :: Ecto.Changeset.t() | String.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: EconomicResource.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(EconomicResource, id)
end

@spec update(id(), params()) :: {:ok, EconomicResource.t()} | {:error, error}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &EconomicResource.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: er}} -> {:ok, er}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, EconomicResource.t()} | {:error, error}
def delete(id) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.delete(:delete, &(&1.get))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: er}} -> {:ok, er}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(EconomicResource.t(), :conforms_to | :accounting_quantity
		| :onhand_quantity | :primary_accountable | :custodian
		| :stage | :state | :current_location | :lot | :contained_in
		| :unit_of_effort)
	:: EconomicResource.t()
def preload(eco_res, :conforms_to) do
	Repo.preload(eco_res, :conforms_to)
end

def preload(eco_res, :accounting_quantity) do
	Measure.preload(eco_res, :accounting_quantity)
end

def preload(eco_res, :onhand_quantity) do
	Measure.preload(eco_res, :onhand_quantity)
end

def preload(eco_res, :primary_accountable) do
	Repo.preload(eco_res, :primary_accountable)
end

def preload(eco_res, :custodian) do
	Repo.preload(eco_res, :custodian)
end

def preload(eco_res, :stage) do
	Repo.preload(eco_res, :stage)
end

def preload(eco_res, :state) do
	Action.preload(eco_res, :state)
end

def preload(eco_res, :current_location) do
	Repo.preload(eco_res, :current_location)
end

def preload(eco_res, :lot) do
	Repo.preload(eco_res, :lot)
end

def preload(eco_res, :contained_in) do
	Repo.preload(eco_res, :contained_in)
end

def preload(eco_res, :unit_of_effort) do
	Repo.preload(eco_res, :unit_of_effort)
end

# Returns a EconomicResource in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id()) :: (repo(), changes() -> {:ok, EconomicResource.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			er -> {:ok, er}
		end
	end
end
end
