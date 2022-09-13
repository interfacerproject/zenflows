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

defmodule Zenflows.VF.ResourceSpecification.Domain do
@moduledoc "Domain logic of ResourceSpecifications."

alias Ecto.Multi
alias Zenflows.DB.{Paging, Repo}
alias Zenflows.VF.ResourceSpecification

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id() | map() | Keyword.t())
	:: {:ok, ResourceSpecification.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(ResourceSpecification, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec all(Paging.params()) :: Paging.result()
def all(params) do
	Paging.page(ResourceSpecification, params)
end

@spec create(repo(), params())
	:: {:ok, ResourceSpecification.t()} | {:error, chgset()}
def create(repo \\ Repo, params) do
	Multi.new()
	|> Multi.insert(:insert, ResourceSpecification.chgset(params))
	|> repo.transaction()
	|> case do
		{:ok, %{insert: rs}} -> {:ok, rs}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params())
	:: {:ok, ResourceSpecification.t()} | {:error, String.t() | chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.update(:update, &ResourceSpecification.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: rs}} -> {:ok, rs}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id())
	:: {:ok, ResourceSpecification.t()} | {:error, String.t() | chgset()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.delete(:delete, & &1.one)
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: rs}} -> {:ok, rs}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(ResourceSpecification.t(),
		:images | :default_unit_of_resource | :default_unit_of_effort)
	:: ResourceSpecification.t()
def preload(res_spec, :images) do
	Repo.preload(res_spec, :images)
end

def preload(res_spec, :default_unit_of_resource) do
	Repo.preload(res_spec, :default_unit_of_resource)
end

def preload(res_spec, :default_unit_of_effort) do
	Repo.preload(res_spec, :default_unit_of_effort)
end
end
