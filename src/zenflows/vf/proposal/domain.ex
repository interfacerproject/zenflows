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

defmodule Zenflows.VF.Proposal.Domain do
@moduledoc "Domain logic of Proposals."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.Proposal

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id()) :: {:ok, Proposal.t()} | {:error, String.t()}
def one(repo \\ Repo, id) do
	one_by(repo, id: id)
end

@spec one_by(repo(), map() | Keyword.t())
	:: {:ok, Proposal.t()} | {:error, String.t()}
def one_by(repo \\ Repo, clauses) do
	case repo.get_by(Proposal, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec create(params()) :: {:ok, Proposal.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:insert, Proposal.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{insert: p}} -> {:ok, p}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) ::
	{:ok, Proposal.t()} | {:error, String.t() | chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one_by/2)
	|> Multi.update(:update, &Proposal.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: p}} -> {:ok, p}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id())
	:: {:ok, Proposal.t()} | {:error, String.t() | chgset()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one_by/2)
	|> Multi.delete(:delete, &(&1.one))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: pi}} -> {:ok, pi}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(Proposal.t(), :eligible_location | :publishes
		| :primary_intents | :reciprocal_intents)
	:: Proposal.t()
def preload(prop, :eligible_location) do
	Repo.preload(prop, :eligible_location)
end

def preload(prop, :publishes) do
	Repo.preload(prop, :publishes)
end

def preload(prop, :primary_intents) do
	Repo.preload(prop, :primary_intents)
end

def preload(prop, :reciprocal_intents) do
	Repo.preload(prop, :reciprocal_intents)
end
end
