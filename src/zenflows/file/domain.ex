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

defmodule Zenflows.File.Domain do
@moduledoc "Domain logic of Files."

import Ecto.Query

alias Ecto.{Changeset, Multi}
alias Zenflows.DB.{Repo, Schema}
alias Zenflows.File

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, File.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(File, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: File.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec preload_gql(Schema.t(), atom(), atom()) :: Schema.t()
def preload_gql(record, gql_key, id_key) do
	result = from(f in File,
		join: j in File.Join, on: j.hash == f.hash,
		join: r in ^record.__struct__, on: field(j, ^id_key) == r.id,
		where: r.id == ^record.id,
		order_by: j.inserted_at,
		select: %{
			hash: f.hash,
			size: f.size,
			bin: f.bin,
			name: j.name,
			description: j.description,
			mime_type: j.mime_type,
			extension: j.extension,
			inserted_at: j.inserted_at,
			updated_at: j.updated_at,
		})
	|> Repo.all()
	Map.put(record, gql_key, result)
end

@spec multi_insert(Multi.t(), term(), atom(), atom()) :: Multi.t()
def multi_insert(m, key, files_key, id_key) do
	m
	|> Multi.run("#{key}.files", fn _, %{^key => record} ->
		(Map.get(record, files_key) || [])
		|> Enum.reduce_while({:ok, []}, fn x, {_, list} ->
			x
			|> Map.put(id_key, record.id)
			|> create()
			|> case do
				{:ok, f} -> {:cont, {:ok, [f | list]}}
				{:error, reason} -> {:halt, {:error, reason}}
			end
		end)
		|> case do
			{:ok, file_list} -> {:ok, file_list}
			{:error, reason} -> {:error, reason}
		end
	end)
	|> Multi.run("#{key}.delete_unused_files", fn repo, _ ->
		from(File, as: :f,
			where: not exists(
				from(j in File.Join,
					where: parent_as(:f).hash == j.hash,
					select: 1
				)
			)
		)
		|> repo.delete_all()
		|> case do
			{count, nil} -> {:ok, count}
			_ -> {:error, "couldn't delete"}
		end
	end)
end

@spec multi_update(Multi.t(), term(), atom(), atom()) :: Multi.t()
def multi_update(m, key, files_key, id_key) do
	m
	|> Multi.run("#{key}.delete_old_files", fn repo, %{^key => record} ->
		where(File.Join, ^[{id_key, record.id}])
		|> repo.delete_all()
		|> case do
			{count, nil} -> {:ok, count}
			_ -> {:error, "couldn't delete"}
		end
	end)
	|> multi_insert(key, files_key, id_key)
end

@spec create(Schema.params()) :: {:ok, File.Join.t()} | {:error, Changeset.t()}
def create(params) do
	Repo.multi(fn ->
		with %{valid?: true} = file_cset <- File.changeset(params),
				:ok <- create_file_if_not_exists(file_cset) do
			File.Join.changeset(params) |> Repo.insert()
		end
	end)
end

@spec create_file_if_not_exists(Changeset.t()) :: :ok | {:error, Changeset.t()}
defp create_file_if_not_exists(%{changes: %{hash: hash}} = cset) do
	Repo.multi(fn repo ->
		where(File, hash: ^hash)
		|> repo.exists?()
		|> if do
			:ok
		else
			cset
			|> repo.insert()
			|> case do
				{:ok, _} -> :ok
				{:error, reason} -> {:error, reason}
			end
		end
	end)
end

@spec create!(Schema.params()) :: File.Join.t()
def create!(params) do
	{:ok, value} = create(params)
	value
end

@spec all() :: {:ok, [File.t()]} | {:error, Changeset.t()}
def all() do
	{:ok, Repo.all(File)}
end

@spec all!() :: [File.t()]
def all!() do
	{:ok, value} = all()
	value
end
end
