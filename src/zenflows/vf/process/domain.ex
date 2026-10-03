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

require Logger

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, ObjectControl}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{
	EconomicEvent,
	EconomicResource,
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

@spec trace_dpp_before(Process.t(), non_neg_integer(),
		MapSet.t(), [EconomicResource.t() | EconomicEvent.t() | Process.t()])
	:: {MapSet.t(), [EconomicResource.t() | EconomicEvent.t() | Process.t()]}
def trace_dpp_before(%{id: id}, 0, visited, children) do
	Logger.info(%{type: "Process", id: id, visited: visited, children: children})
	{visited, children}
end
def trace_dpp_before(proc, depth, visited, children) do
	{:ok, result} = Repo.multi(fn ->
		{visited, proc_children} =
			previous(proc)
			|> Enum.reduce({visited, []}, fn evt, {visited, proc_children} ->
				if MapSet.member?(visited, "evt#{evt.id}") do
					{visited, proc_children}
				else
					visited = MapSet.put(visited, "evt#{evt.id}")
					EconomicEvent.Domain.trace_dpp_before(evt, depth - 1, visited, proc_children)
				end
			end)
		child = %{type: "Process", node: proc, children: Enum.reverse(proc_children)}
		children = [child | children]
		{:ok, {visited, children}}
	end)
	result
end

@spec create(ExecutionContext.t(), Schema.params()) :: {:ok, Process.t()} | {:error, term()}
def create(%ExecutionContext{} = ctx, params) do
	Multi.new()
	|> Multi.run(:authz, fn _, _ ->
		with :ok <- Authz.authorize(ctx, "process.create", %Facts{}), do: {:ok, nil}
	end)
	|> Multi.insert(:process, fn _ -> check_group(Process.changeset(params)) end)
	|> ObjectControl.Domain.multi_on_create(ctx, "process", :process)
	|> Repo.transaction()
	|> case do
		{:ok, %{process: proc}} -> {:ok, proc}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec create!(ExecutionContext.t(), Schema.params()) :: Process.t()
def create!(ctx, params) do
	{:ok, value} = create(ctx, params)
	value
end

@spec update(ExecutionContext.t(), Schema.id(), Schema.params()) :: {:ok, Process.t()} | {:error, term()}
def update(%ExecutionContext{} = ctx, id, params) do
	Multi.new()
	|> Authz.multi_authorize(:authz, ctx, "process.update",
		fn repo, _ -> Facts.for_object(repo, ctx, "process", id) end)
	|> Authz.multi_target(:one, :authz)
	|> Multi.update(:process, fn %{one: proc} -> check_group(Process.changeset(proc, params)) end)
	|> Repo.transaction()
	|> case do
		{:ok, %{process: proc}} -> {:ok, proc}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec update!(ExecutionContext.t(), Schema.id(), Schema.params()) :: Process.t()
def update!(ctx, id, params) do
	{:ok, value} = __MODULE__.update(ctx, id, params)
	value
end

@spec delete(ExecutionContext.t(), Schema.id()) :: {:ok, Process.t()} | {:error, term()}
def delete(%ExecutionContext{} = ctx, id) do
	Multi.new()
	|> Authz.multi_authorize(:authz, ctx, "process.delete",
		fn repo, _ -> Facts.for_object(repo, ctx, "process", id) end)
	|> Authz.multi_target(:one, :authz)
	|> Multi.delete(:process, fn %{one: proc} -> proc end)
	|> ObjectControl.Domain.multi_remove(ctx, "process", id)
	|> Repo.transaction()
	|> case do
		{:ok, %{process: proc}} -> {:ok, proc}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec delete!(ExecutionContext.t(), Schema.id()) :: Process.t()
def delete!(ctx, id) do
	{:ok, value} = delete(ctx, id)
	value
end

# A ProcessGroup that groups other ProcessGroups cannot group processes.
defp check_group(%{valid?: true, changes: %{grouped_in_id: gid}} = cset) do
	if where(ProcessGroup, grouped_in_id: ^gid) |> Repo.exists?() do
		Changeset.add_error(cset, :grouped_in_id,
			"this ProcessGroup must not group other ProcessGroups")
	else
		cset
	end
end
defp check_group(cset), do: cset

@spec preload(Process.t(), :based_on | :planned_within | :nested_in | :grouped_in)
	:: Process.t()
def preload(proc, x) when x in ~w[based_on planned_within nested_in grouped_in]a do
	Repo.preload(proc, x)
end
end
