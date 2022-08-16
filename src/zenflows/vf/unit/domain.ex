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

defmodule Zenflows.VF.Unit.Domain do
@moduledoc "Domain logic of Units."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.Unit

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id()) :: {:ok, Unit.t()} | {:error, String.t()}
def one(repo \\ Repo, id) do
	one_by(repo, id: id)
end

@spec one_by(repo(), map() | Keyword.t())
	:: {:ok, Unit.t()} | {:error, String.t()}
def one_by(repo \\ Repo, clauses) do
	case repo.get_by(Unit, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

# `repo` is needed since we use that in a migration script.
@spec create(repo(), params()) :: {:ok, Unit.t()} | {:error, chgset()}
def create(repo \\ Repo, params) do
	Multi.new()
	|> Multi.insert(:insert, Unit.chgset(params))
	|> repo.transaction()
	|> case do
		{:ok, %{insert: u}} -> {:ok, u}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, Unit.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one_by/2)
	|> Multi.update(:update, &Unit.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: u}} -> {:ok, u}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, Unit.t()} | {:error, chgset()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one_by/2)
	|> Multi.delete(:delete, &(&1.one))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: u}} -> {:ok, u}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end
end
