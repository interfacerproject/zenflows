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

defmodule Zenflows.VF.Plan.Domain do
@moduledoc "Domain logic of Plans."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.Plan

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id()) :: {:ok, Plan.t()} | {:error, String.t()}
def one(repo \\ Repo, id) do
	one_by(repo, id: id)
end

@spec one_by(repo(), map() | Keyword.t())
	:: {:ok, Plan.t()} | {:error, String.t()}
def one_by(repo \\ Repo, clauses) do
	case repo.get_by(Plan, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec create(params()) :: {:ok, Plan.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:insert, Plan.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{insert: p}} -> {:ok, p}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) ::
	{:ok, Plan.t()} | {:error, String.t() | chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one_by/2)
	|> Multi.update(:update, &Plan.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: p}} -> {:ok, p}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, Plan.t()} | {:error, String.t() | chgset()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one_by/2)
	|> Multi.delete(:delete, &(&1.one))
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
end
