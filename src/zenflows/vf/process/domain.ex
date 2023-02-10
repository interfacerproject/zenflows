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

defmodule Zenflows.VF.Process.Domain do
@moduledoc "Domain logic of Processes."

import Ecto.Query

alias Ecto.Changeset
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{
	EconomicEvent,
	Process,
	Process.Query,
	ProcessGroup,
}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, Process.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(Process, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: Process.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [Process.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	{:ok, Page.all(Process, page)}
end

@spec all!(Page.t()) :: [Process.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec previous(Process.t() | Schema.id()) :: [EconomicEvent.t()]
def previous(_, _ \\ Page.new())
def previous(%Process{id: id}, page), do: previous(id, page)
def previous(id, page) do
	Query.previous(id)
	|> Page.all(page)
	|> Enum.sort(&(
		&1.previous_event_id == nil
		or &1.id == &2.previous_event_id
		or &1.id <= &2.id))
	|> Enum.reverse()
end

@spec create(Schema.params()) :: {:ok, Process.t()} | {:error, Changeset.t()}
def create(params) do
	Repo.multi(fn ->
		case Process.changeset(params) do
			%{valid?: true, changes: %{grouped_in_id: gid}} = cset ->
				if where(ProcessGroup, grouped_in_id: ^gid) |> Repo.exists?() do
					Changeset.add_error(cset, :grouped_in_id,
						"this ProcessGroup must not group other ProcessGroups")
				else
					cset
				end
			cset ->
				cset
		end
		|> Repo.insert()
	end)
end

@spec create!(Schema.params()) :: Process.t()
def create!(params) do
	{:ok, value} = create(params)
	value
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, Process.t()} | {:error, String.t() | Changeset.t()}
def update(id, params) do
	Repo.multi(fn ->
		with {:ok, proc} <- one(id) do
			case Process.changeset(proc, params) do
				%{valid?: true, changes: %{grouped_in_id: gid}} = cset ->
					if where(ProcessGroup, grouped_in_id: ^gid) |> Repo.exists?() do
						Changeset.add_error(cset, :grouped_in_id,
							"this ProcessGroup must not group other ProcessGroups")
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

@spec update!(Schema.id(), Schema.params()) :: Process.t()
def update!(id, params) do
	{:ok, value} = __MODULE__.update(id, params)
	value
end

@spec delete(Schema.id()) :: {:ok, Process.t()} | {:error, String.t() | Changeset.t()}
def delete(id) do
	Repo.multi(fn ->
		with {:ok, proc} <- one(id) do
			Repo.delete(proc)
		end
	end)
end

@spec delete!(Schema.id()) :: Process.t()
def delete!(id) do
	{:ok, value} = delete(id)
	value
end

@spec preload(Process.t(), :based_on | :planned_within | :nested_in | :grouped_in)
	:: Process.t()
def preload(proc, x) when x in ~w[based_on planned_within nested_in grouped_in]a do
	Repo.preload(proc, x)
end
end
