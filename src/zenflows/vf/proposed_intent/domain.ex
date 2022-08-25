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

defmodule Zenflows.VF.ProposedIntent.Domain do
@moduledoc "Domain logic of ProposedIntents."

alias Ecto.Multi
alias Zenflows.DB.{Paging, Repo}
alias Zenflows.VF.ProposedIntent

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id() | map() | Keyword.t())
	:: {:ok, ProposedIntent.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(ProposedIntent, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec all(Paging.params()) :: Paging.result()
def all(params) do
	Paging.page(ProposedIntent, params)
end

@spec create(params()) :: {:ok, ProposedIntent.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:insert, ProposedIntent.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{insert: pi}} -> {:ok, pi}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec delete(id())
	:: {:ok, ProposedIntent.t()} | {:error, String.t() | chgset()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one/2)
	|> Multi.delete(:delete, & &1.one)
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: pi}} -> {:ok, pi}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(ProposedIntent.t(), :published_in | :publishes)
	:: ProposedIntent.t()
def preload(prop_int, :published_in) do
	Repo.preload(prop_int, :published_in)
end

def preload(prop_int, :publishes) do
	Repo.preload(prop_int, :publishes)
end
end
