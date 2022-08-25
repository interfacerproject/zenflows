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

defmodule Zenflows.DB.Paging do
@moduledoc "Paging helpers for Domain modules."

import Ecto.Query

alias Zenflows.DB.{ID, Repo}

@type result() :: {:ok, t()} | {:error, String.t()}

@type t() :: %{
	page_info: page_info(),
	edges: [edges()],
}

@type page_info() :: %{
	start_cursor: ID.t() | nil,
	end_cursor: ID.t() | nil,
	has_previous_page: boolean(),
	has_next_page: boolean(),
	total_count: non_neg_integer(),
	page_limit: non_neg_integer(),
}

@type edges() :: %{
	cursor: ID.t(),
	node: struct(),
}

@type params() :: %{first: non_neg_integer(), after: ID.t()}
	| %{last: non_neg_integer, before: ID.t()}

@spec def_page_size() :: non_neg_integer()
def def_page_size() do
	conf()[:def_page_size]
end

@spec max_page_size() :: non_neg_integer()
def max_page_size() do
	conf()[:max_page_size]
end

@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, Zenflows.GQL)
end

@spec parse(params()) :: {:error, String.t()} | {:ok, {:forw | :back, ID.t() | nil, non_neg_integer()}}
def parse(%{first: _, last: _}),   do: {:error, "first and last can't be provided at the same time"}
def parse(%{after: _, before: _}), do: {:error, "after and before can't be provided at the same time"}

def parse(%{after: _, last: _}),   do: {:error, "after and last can't be provided at the same time"}
def parse(%{before: _, first: _}), do: {:error, "before and first can't be provided at the same time"}

def parse(%{first: num}) when num < 0, do: {:error, "first must be positive"}
def parse(%{last: num})  when num < 0, do: {:error, "last must be positive"}

def parse(%{after: cur, first: num}), do: {:ok, {:forw, cur, normalize(num)}}
def parse(%{after: cur}),             do: {:ok, {:forw, cur, def_page_size()}}

def parse(%{before: cur, last: num}), do: {:ok, {:back, cur, normalize(num)}}
def parse(%{before: cur}),            do: {:ok, {:back, cur, def_page_size()}}

def parse(%{first: num}), do: {:ok, {:forw, nil, normalize(num)}}
def parse(%{last: num}),  do: {:ok, {:back, nil, normalize(num)}}

def parse(_), do: {:ok, {:forw, nil, def_page_size()}}

@spec normalize(integer()) :: non_neg_integer()
defp normalize(num) do
	# credo:disable-for-next-line Credo.Check.Refactor.MatchInCondition
	if num > (max = max_page_size()),
		do: max,
		else: num
end

@doc """
Page Ecto schemas.

Only supports forward or backward paging with or without cursors.
"""
@spec page(atom() | Ecto.Query.t(), params()) :: result()
def page(schema_or_query, params) do
	with {:ok, {dir, cur, num}} <- parse(params) do
		{page_fun, order_by} =
			case dir do
				:forw -> {&forw/3, [asc: :id]}
				:back -> {&back/3, [desc: :id]}
			end
		where =
			case {dir, cur} do
				{_, nil} -> []
				{:forw, cur} -> dynamic([s], s.id > ^cur)
				{:back, cur} -> dynamic([s], s.id < ^cur)
			end
		{:ok,
			from(s in schema_or_query,
				where: ^where,
				order_by: ^order_by,
				limit: ^num + 1,
				select: %{cursor: s.id, node: s})
			|> Repo.all()
			|> page_fun.(cur, num)}
	end
end

@spec forw(edges(), ID.t() | nil, non_neg_integer()) :: t()
def forw(edges, cur, num) do
	{edges, count} =
		Enum.reduce(edges, {[], 0}, fn e, {edges, count} ->
			{[e | edges], count + 1}
		end)

	{edges, has_next?, count} =
		# we indeed have fetched num+1 records
		if count - 1 == num do
			[_ | edges] = edges
			{edges, true, count - 1}
		else
			{edges, false, count}
		end

	{edges, first, last} =
		case edges do
			[] -> {[], nil, nil}
			_ ->
				[last | _] = edges
				[first | _] = edges = Enum.reverse(edges)
				{edges, first, last}
		end

	%{
		edges: edges,
		page_info: %{
			start_cursor: first[:cursor],
			end_cursor: last[:cursor],
			has_next_page: has_next?,
			has_previous_page: cur != nil,
			total_count: count,
			page_limit: num,
		},
	}
end

@spec back(edges(), ID.t() | nil, non_neg_integer()) :: t()
def back(edges, cur, num) do
	# Currently, this part of the algorithm doesn't care about
	# whether we do forward or backward paging.
	forw(edges, cur, num)
end
end
