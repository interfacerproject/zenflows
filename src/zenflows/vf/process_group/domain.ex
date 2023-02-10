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

defmodule Zenflows.VF.ProcessGroup.Domain do
@moduledoc "Domain logic of ProcessGroups."

import Ecto.Query

alias Ecto.Changeset
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{Process, ProcessGroup}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, ProcessGroup.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(ProcessGroup, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: ProcessGroup.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [ProcessGroup.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	{:ok, Page.all(ProcessGroup, page)}
end

@spec all!(Page.t()) :: [ProcessGroup.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec groups(Schema.id(), Page.t()) ::
	{:ok, [Process.t()] | [ProcessGroup.t()]} | {:error, Changeset.t()}
def groups(id, page \\ Page.new()) do
	Repo.multi(fn ->
		{:ok, with [] <- where(Process, grouped_in_id: ^id) |> Page.all(page) do
			where(ProcessGroup, grouped_in_id: ^id) |> Page.all(page)
		end}
	end)
end

@spec create(Schema.params()) :: {:ok, ProcessGroup.t()} | {:error, Changeset.t()}
def create(params) do
	Repo.multi(fn ->
		case ProcessGroup.changeset(params) do
			%{valid?: true, changes: %{grouped_in_id: gid}} = cset ->
				if where(Process, grouped_in_id: ^gid) |> Repo.exists?() do
					Changeset.add_error(cset, :grouped_in_id,
						"this ProcessGroup must not group Processes")
				else
					cset
				end
			cset ->
				cset
		end
		|> Repo.insert()
	end)
end

@spec create!(Schema.params()) :: ProcessGroup.t()
def create!(params) do
	{:ok, value} = create(params)
	value
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, ProcessGroup.t()} | {:error, String.t() | Changeset.t()}
def update(id, params) do
	Repo.multi(fn ->
		with {:ok, procgrp} <- one(id) do
			case ProcessGroup.changeset(procgrp, params) do
				%{valid?: true, changes: %{grouped_in_id: gid}} = cset ->
					if where(Process, grouped_in_id: ^gid) |> Repo.exists?() do
						Changeset.add_error(cset, :grouped_in_id,
							"this ProcessGroup must not group Processes")
					else
						cset
					end
				cset ->
					cset
			end
			|> Repo.update()
		end
	end)
end

@spec update!(Schema.id(), Schema.params()) :: ProcessGroup.t()
def update!(id, params) do
	{:ok, value} = __MODULE__.update(id, params)
	value
end

@spec delete(Schema.id()) :: {:ok, ProcessGroup.t()} | {:error, String.t() | Changeset.t()}
def delete(id) do
	Repo.multi(fn ->
		with {:ok, procgrp} <- one(id) do
			Repo.delete(procgrp)
		end
	end)
end

@spec delete!(Schema.id()) :: ProcessGroup.t()
def delete!(id) do
	{:ok, value} = delete(id)
	value
end

@spec preload(ProcessGroup.t(), :grouped_in) :: ProcessGroup.t()
def preload(proc, :grouped_in) do
	Repo.preload(proc, :grouped_in)
end
end
