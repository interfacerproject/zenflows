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

defmodule Zenflows.VF.Process.Domain do
@moduledoc "Domain logic of Processes."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.Process

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep changes() :: Ecto.Multi.changes()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec by_id(repo(), id()) :: Process.t() | nil
def by_id(repo \\ Repo, id) do
	repo.get(Process, id)
end

@spec create(params()) :: {:ok, Process.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:proc, Process.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{proc: p}} -> {:ok, p}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) :: {:ok, Process.t()} | {:error, chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.run(:get, multi_get(id))
	|> Multi.update(:update, &Process.chgset(&1.get, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: p}} -> {:ok, p}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, Process.t()} | {:error, chgset()}
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

@spec preload(Process.t(), :based_on | :planned_within | :nested_in)
	:: Process.t()
def preload(proc, :based_on) do
	Repo.preload(proc, :based_on)
end

def preload(proc, :planned_within) do
	Repo.preload(proc, :planned_within)
end

def preload(proc, :nested_in) do
	Repo.preload(proc, :nested_in)
end

# Returns a Process in ok-err tuple from given ID.  Used inside
# Ecto.Multi.run/5 to get a record in transaction.
@spec multi_get(id())
	:: (repo(), changes() -> {:ok, Process.t()} | {:error, String.t()})
defp multi_get(id) do
	fn repo, _ ->
		case by_id(repo, id) do
			nil -> {:error, "not found"}
			p -> {:ok, p}
		end
	end
end
end
