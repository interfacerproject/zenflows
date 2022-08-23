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
alias Zenflows.GQL.Paging
alias Zenflows.VF.{
	Action,
	EconomicResource,
	Measure,
}

@typep repo() :: Ecto.Repo.t()
@typep error() :: Ecto.Changeset.t() | String.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id() | map() | Keyword.t())
	:: {:ok, EconomicResource.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(EconomicResource, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec all(Paging.params()) :: Paging.result(EconomicResource.t())
def all(params) do
	Paging.page(EconomicResource, params)
end

@spec update(id(), params()) :: {:ok, EconomicResource.t()} | {:error, error()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.update(:update, &EconomicResource.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: er}} -> {:ok, er}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, EconomicResource.t()} | {:error, error()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.delete(:delete, & &1.one)
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
end
