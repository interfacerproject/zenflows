# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.Intent.Domain do
@moduledoc "Domain logic of Intents."

alias Ecto.{Changeset, Multi}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{
	Action,
	Intent,
	Measure,
}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, Intent.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(Intent, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: Intent.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [Intent.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	{:ok, Page.all(Intent, page)}
end

@spec all!(Page.t()) :: [Intent.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec create(Schema.params()) :: {:ok, Intent.t()} | {:error, Changeset.t()}
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

@spec create!(Schema.params()) :: Intent.t()
def create!(params) do
	{:ok, value} = create(params)
	value
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, Intent.t()} | {:error, String.t() | Changeset.t()}
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

@spec update!(Schema.id(), Schema.params()) :: Intent.t()
def update!(id, params) do
	{:ok, value} = update(id, params)
	value
end

@spec delete(Schema.id()) :: {:ok, Intent.t()} | {:error, String.t() | Changeset.t()}
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

@spec delete!(Schema.id) :: Intent.t()
def delete!(id) do
	{:ok, value} = delete(id)
	value
end

@spec preload(Intent.t(), :action | :input_of | :output_of
		| :provider | :receiver
		| :resource_inventoried_as  | :resource_conforms_to
		| :resource_quantity | :effort_quantity | :available_quantity
		| :at_location | :published_in)
	:: Intent.t()
def preload(int, x) when x in ~w[
	input_of output_of provider receiver resource_inventoried_as
	resource_conforms_to at_location published_in
]a,
	do: Repo.preload(int, x)
def preload(int, :action), do: Action.preload(int, :action)
def preload(int, x) when x in ~w[
	effort_quantity available_quantity resource_quantity
]a,
	do: Measure.preload(int, x)

@spec multi_key() :: atom()
def multi_key(), do: :intent

@spec multi_one(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_one(m, key \\ multi_key(), id) do
	Multi.run(m, key, fn repo, _ -> one(repo, id) end)
end

@spec multi_insert(Multi.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, key \\ multi_key(), params) do
	Multi.insert(m, key, Intent.changeset(params))
end

@spec multi_update(Multi.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, key \\ multi_key(), id, params) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.update(key,
		&Intent.changeset(Map.fetch!(&1, "#{key}.one"), params))
end

@spec multi_delete(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, key \\ multi_key(), id) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end
end
