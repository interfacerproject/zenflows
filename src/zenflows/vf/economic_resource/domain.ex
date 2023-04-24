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

defmodule Zenflows.VF.EconomicResource.Domain do
@moduledoc "Domain logic of EconomicResources."

require Logger

alias Ecto.{Changeset, Multi}
alias Zenflows.File
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{
	Action,
	EconomicEvent,
	EconomicResource,
	EconomicResource.Query,
	Measure,
	Process,
}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, EconomicResource.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(EconomicResource, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: EconomicResource.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [EconomicResource.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	with {:ok, q} <- Query.all(page) do
		{:ok, Page.all(q, page)}
	end
end

@spec all!(Page.t()) :: [EconomicResource.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec previous(EconomicResource.t() | Schema.id()) :: [EconomicEvent.t()]
def previous(_, _ \\ Page.new())
def previous(%EconomicResource{id: id}, page), do: previous(id, page)
def previous(id, page) do
	Query.previous(id)
	|> Page.all(page)
	|> Enum.sort(&(
		&1.previous_event_id == nil
		or &1.id == &2.previous_event_id
		or &1.id <= &2.id))
	|> Enum.reverse()
end

@spec trace(EconomicResource.t() | EconomicEvent.t() | Process.t(), Page.t())
	:: [EconomicResource.t() | EconomicEvent.t() | Process.t()]
def trace(item, _page \\ Page.new()) do
	flows = [item]
	visited = MapSet.new([{item.__struct__, item.id}])
	{contained, modified, delivered} =
		case item do
			%EconomicEvent{action_id: "unpack"} ->
				{MapSet.new([item.resource_inventoried_as_id]), %MapSet{}, %MapSet{}}
			%EconomicEvent{action_id: "modify"} ->
				{%MapSet{}, MapSet.new([item.resource_inventoried_as_id]), %MapSet{}}
			%EconomicEvent{action_id: "dropoff"} ->
				{%MapSet{}, %MapSet{}, MapSet.new([item.resource_inventoried_as_id])}
			_ ->
				{%MapSet{}, %MapSet{}, %MapSet{}}
		end
	{flows, _, _, _, _, _} = trace_depth_first_search(flows, visited, contained, modified, delivered, nil)
	Enum.reverse(flows)
end

@spec trace_depth_first_search([EconomicResource.t() | EconomicEvent.t() | Process.t()],
		MapSet.t(), MapSet.t(), MapSet.t(), MapSet.t(), nil | EconomicResource.t())
	:: {[EconomicResource.t() | EconomicEvent.t() | Process.t()],
		MapSet.t(), MapSet.t(), MapSet.t(), MapSet.t(), nil | EconomicResource.t()}
defp trace_depth_first_search(flows, visited, contained, modified, delivered, saved_event) do
	[last | _] = flows
	previous =
		case last do
			%EconomicResource{} -> EconomicResource.Domain.previous(last)
			%EconomicEvent{} -> [EconomicEvent.Domain.previous(last)]
			%Process{} -> Process.Domain.previous(last)
		end
	saved_event = if match?(%EconomicEvent{}, last),
		do: EconomicEvent.Domain.preload(last, :previous_event).previous_event,
		else: saved_event
	previous =
		case {previous, saved_event} do
			# ensure that:
			# * `previous` has at least one item that is not `nil` (events' previous can return `nil`)
			# * `saved_event` is not `nil` (events like raise have nullable previous_event)
			{[%EconomicResource{}], %EconomicEvent{}} ->
				[saved_event | previous]

			{[%{id: _} | _], %{id: id}} ->
				case Enum.split_while(previous, &(&1.id != id)) do
					{left, [found | right]} -> [found | left] ++ right
					{left, []} -> left
				end
			_ ->
				previous
		end
	Enum.reduce(previous, {flows, visited, contained, modified, delivered, saved_event},
		fn item, {flows, visited, contained, modified, delivered, saved_event} ->
			if item != nil and not MapSet.member?(visited, {item.__struct__, item.id}) do
				{flows, visited, contained, modified, delivered, saved_event} =
					handle_set(:delivered, item, flows, visited, contained, modified, delivered, saved_event)
				{flows, visited, contained, modified, delivered, saved_event} =
					handle_set(:modified, item, flows, visited, contained, modified, delivered, saved_event)
				{flows, visited, contained, modified, delivered, saved_event} =
					handle_set(:contained, item, flows, visited, contained, modified, delivered, saved_event)
				case item do
					%EconomicEvent{action_id: id}
							when id in ~w[pickup dropoff accept modify pack unpack] ->
						{flows, visited, contained, modified, delivered, saved_event}
					_ ->
						visited = MapSet.put(visited, {item.__struct__, item.id})
						flows = [item | flows]
						trace_depth_first_search(flows, visited, contained, modified, delivered, saved_event)
				end
			else
				{flows, visited, contained, modified, delivered, saved_event}
			end
		end)
end

@spec handle_set(:delivered | :modified | :contained, EconomicEvent.t(),
		[EconomicResource.t() | EconomicEvent.t() | Process.t()],
		MapSet.t(), MapSet.t(), MapSet.t(), MapSet.t(), nil | EconomicEvent.t())
	:: {[EconomicResource.t() | EconomicEvent.t() | Process.t()],
		MapSet.t(), MapSet.t(), MapSet.t(), MapSet.t(), nil | EconomicEvent.t()}
for name <- [:delivered, :modified, :contained] do
	set = Macro.var(name, nil)
	{action0, action1} = case name do
		:delivered -> {"pickup", "dropoff"}
		:modified -> {"accept", "modify"}
		:contained -> {"pack", "unpack"}
	end
	defp handle_set(unquote(name), %EconomicEvent{action_id: unquote(action0)} = evt,
			flows, visited, contained, modified, delivered, saved_event) do
		if MapSet.member?(unquote(set), {EconomicResource, evt.resource_inventoried_as_id}) do
			unquote(set) = MapSet.delete(unquote(set), {EconomicResource, evt.resource_inventoried_as_id})
			visited = MapSet.put(visited, {EconomicEvent, evt.id})
			flows = [evt | flows]
			trace_depth_first_search(flows, visited, contained, modified, delivered, saved_event)
		else
			{flows, visited, contained, modified, delivered, saved_event}
		end
	end
	defp handle_set(unquote(name), %EconomicEvent{action_id: unquote(action1)} = evt,
			flows, visited, contained, modified, delivered, saved_event) do
		unquote(set) = MapSet.put(unquote(set), {EconomicResource, evt.resource_inventoried_as_id})
		visited = MapSet.put(visited, {EconomicEvent, evt.id})
		flows = [evt | flows]
		trace_depth_first_search(flows, visited, contained, modified, delivered, saved_event)
	end
end
defp handle_set(_, _, flows, visited, contained, modified, delivered, saved_event),
	do: {flows, visited, contained, modified, delivered, saved_event}

@spec trace_dpp(EconomicResource.t()) :: [EconomicResource.t() | EconomicEvent.t() | Process.t()]
def trace_dpp(res) do
	{:ok, result} = Repo.multi(fn ->
		# the initial value for `_depth_countdown` was taken from:
		# https://github.com/interfacerproject/Interfacer-notebook/blob/326750b1cae445ce5faa0fafb057e50538077910/if_consts.py#L25
		{_visited, children} =
			trace_dpp_before(res, _depth_countdown = 100_000_000, _visited = MapSet.new(), _children = [])
		{:ok, Enum.reverse(children)}
	end)
	result
end

@spec trace_dpp_before(EconomicResource.t(), non_neg_integer(),
		MapSet.t(), [EconomicResource.t() | EconomicEvent.t() | Process.t()])
	:: {MapSet.t(), [EconomicResource.t() | EconomicEvent.t() | Process.t()]}
def trace_dpp_before(%{id: id}, 0, visited, children) do
	Logger.info(%{type: "EconomicResource", id: id, visited: visited, children: children})
	{visited, children}
end
def trace_dpp_before(res, depth, visited, children) do
	{:ok, result} = Repo.multi(fn ->
		{visited, res_children} =
			previous(res)
			|> Enum.reduce({visited, []}, fn evt, {visited, res_children}  ->
				if MapSet.member?(visited, "evt#{evt.id}") do
					{visited, res_children}
				else
					visited = MapSet.put(visited, "evt#{evt.id}")
					EconomicEvent.Domain.trace_dpp_before(evt, depth - 1, visited, res_children)
				end
			end)
		child = %{type: "EconomicResource", node: res, children: Enum.reverse(res_children)}
		children = [child | children]
		{:ok, {visited, children}}
	end)
	result
end

@spec classifications(Page.t()) :: {:ok, [String.t()]} | {:error, Changeset.t()}
def classifications(page \\ Page.new()) do
	with {:ok, q} <- Query.classifications(page) do
		{:ok, Repo.all(q)}
	end
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, EconomicResource.t()} | {:error, String.t() | Changeset.t()}
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

@spec update!(Schema.id(), Schema.params()) :: EconomicResource.t()
def update!(id, params) do
	{:ok, value} = update(id, params)
	value
end

@spec delete(Schema.id()) ::
	{:ok, EconomicResource.t()} | {:error, String.t() | Changeset.t()}
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

@spec delete!(Schema.id) :: EconomicResource.t()
def delete!(id) do
	{:ok, value} = delete(id)
	value
end

@spec preload(EconomicResource.t(), :images
		| :conforms_to | :accounting_quantity
		| :onhand_quantity | :primary_accountable | :custodian
		| :stage | :state | :current_location | :lot | :contained_in
		| :unit_of_effort | :previous_event)
	:: EconomicResource.t()
def preload(eco_res, x) when x in ~w[
	conforms_to primary_accountable custodian lot
	stage current_location contained_in unit_of_effort previous_event
]a,
	do: Repo.preload(eco_res, x)
def preload(eco_res, x) when x in ~w[accounting_quantity onhand_quantity]a,
	do: Measure.preload(eco_res, x)
def preload(eco_res, :state),
	do: Action.preload(eco_res, :state)
def preload(eco_res, :images),
	do: File.Domain.preload_gql(eco_res, :images, :economic_resource_id)

@spec multi_key() :: atom()
def multi_key(), do: :economic_resource

@spec multi_one(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_one(m, key \\ multi_key(), id) do
	Multi.run(m, key, fn repo, _ -> one(repo, id) end)
end

@spec multi_insert(Multi.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, key \\ multi_key(), params) do
	m
	|> Multi.insert(key, EconomicResource.changeset(params))
	|> File.Domain.multi_insert(key, :images, :economic_resource_id)
end

@spec multi_update(Multi.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, key \\ multi_key(), id, params) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.update(key,
		&EconomicResource.changeset(Map.fetch!(&1, "#{key}.one"), params))
	|> File.Domain.multi_update(key, :images, :economic_resource_id)
end

@spec multi_delete(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, key \\ multi_key(), id) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end
end
