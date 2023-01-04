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

defmodule Zenflows.VF.Satisfaction.Domain do
@moduledoc "Domain logic of Satisfactions."

alias Ecto.{Changeset, Multi}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{Measure, Satisfaction}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, Satisfaction.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(Satisfaction, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: Satisfaction.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [Satisfaction.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	{:ok, Page.all(Satisfaction, page)}
end

@spec all!(Page.t()) :: [Satisfaction.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec create(Schema.params()) :: {:ok, Satisfaction.t()} | {:error, Changeset.t()}
def create(params) do
	key = multi_key()
	Multi.new()
	|> multi_insert(params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec create!(Schema.params()) :: Satisfaction.t()
def create!(params) do
	{:ok, value} = create(params)
	value
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, Satisfaction.t()} | {:error, String.t() | Changeset.t()}
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

@spec update!(Schema.id(), Schema.params()) :: Satisfaction.t()
def update!(id, params) do
	{:ok, value} = update(id, params)
	value
end

@spec delete(Schema.id()) :: {:ok, Satisfaction.t()} | {:error, String.t() | Changeset.t()}
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

@spec delete!(Schema.id) :: Satisfaction.t()
def delete!(id) do
	{:ok, value} = delete(id)
	value
end

@spec preload(Satisfaction.t(), :satisfies | :satisfied_by_event
		| :satisfied_by_commitment | :resource_quantity | :effort_quantity)
	:: Satisfaction.t()
def preload(satis, x) when x in ~w[
	satisfies satisfied_by_event satisfied_by_commitment
]a,
	do: Repo.preload(satis, x)
def preload(satis, x) when x in ~w[effort_quantity resource_quantity]a,
	do: Measure.preload(satis, x)

@spec multi_key() :: atom()
def multi_key(), do: :satisfaction

@spec multi_one(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_one(m, key \\ multi_key(), id) do
	Multi.run(m, key, fn repo, _ -> one(repo, id) end)
end

@spec multi_insert(Multi.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, key \\ multi_key(), params) do
	Multi.insert(m, key, Satisfaction.changeset(params))
end

@spec multi_update(Multi.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, key \\ multi_key(), id, params) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.update(key,
		&Satisfaction.changeset(Map.fetch!(&1, "#{key}.one"), params))
end

@spec multi_delete(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, key \\ multi_key(), id) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end
end
