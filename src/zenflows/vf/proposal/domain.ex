# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

alias Ecto.{Changeset, Multi}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{Proposal, Proposal.Query}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, Proposal.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(Proposal, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: Proposal.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [Proposal.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	with {:ok, q} <- Query.all(page) do
		{:ok, Page.all(q, page)}
	end
end

@spec all!(Page.t()) :: [Proposal.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec status(Proposal.t() | Schema.id())
	:: {:ok, :pending | :accepted | :refused} | {:error, String.t()}
def status(%Proposal{id: id}), do: status(id)
def status(id) do
	Query.status(id)
	|> Repo.one()
	|> case do
		nil -> {:error, "not found"}
		{true, _, 0} ->
			{:ok, :refused}
		{_, intents, satisfactions} when intents == satisfactions ->
			{:ok, :accepted}
		_ ->
			{:ok, :pending}
	end
end

@spec create(Schema.params()) :: {:ok, Proposal.t()} | {:error, Changeset.t()}
def create(params) do
	key = multi_key()
	Multi.new()
	|> multi_insert(params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec create!(Schema.params()) :: Proposal.t()
def create!(params) do
	{:ok, value} = create(params)
	value
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, Proposal.t()} | {:error, String.t() | Changeset.t()}
def update(id, params) do
	key = multi_key()
	Multi.new()
	|> multi_update(id, params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec update!(Schema.id(), Schema.params()) :: Proposal.t()
def update!(id, params) do
	{:ok, value} = update(id, params)
	value
end

@spec delete(Schema.id())
	:: {:ok, Proposal.t()} | {:error, String.t() | Changeset.t()}
def delete(id) do
	key = multi_key()
	Multi.new()
	|> multi_delete(id)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec delete!(Schema.id()) :: Proposal.t()
def delete!(id) do
	{:ok, value} = delete(id)
	value
end

@spec preload(Proposal.t(), :eligible_location | :publishes
		| :primary_intents | :reciprocal_intents)
	:: Proposal.t()
def preload(prop, x) when x in ~w[
	eligible_location publishes primary_intents reciprocal_intents
]a do
	Repo.preload(prop, x)
end

@spec multi_key() :: atom()
def multi_key(), do: :proposal

@spec multi_one(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_one(m, key \\ multi_key(), id) do
	Multi.run(m, key, fn repo, _ -> one(repo, id) end)
end

@spec multi_insert(Multi.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, key \\ multi_key(), params) do
	Multi.insert(m, key, Proposal.changeset(params))
end

@spec multi_update(Multi.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, key \\ multi_key(), id, params) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.update(key,
		&Proposal.changeset(Map.fetch!(&1, "#{key}.one"), params))
end

@spec multi_delete(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, key \\ multi_key(), id) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end
end
