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

defmodule Zenflows.GQL.Connection do
@moduledoc "GraphQL Relay Connection helpers."

alias Ecto.Changeset
alias Zenflows.DB.{ID, Page, Schema, Validate}

@enforce_keys [:page_info, :edges]
defstruct @enforce_keys

@type t() :: %__MODULE__{
	page_info: page_info(),
	edges: [edge()],
}

@type page_info() :: %{
	start_cursor: ID.t() | nil,
	end_cursor: ID.t() | nil,
	has_previous_page: boolean(),
	has_next_page: boolean(),
	total_count: non_neg_integer(),
	page_limit: non_neg_integer(),
}

@type edge() :: %{
	cursor: ID.t(),
	node: Ecto.Schema.t(),
}

@doc """
Converts the given list of schemas (that you get by using
`Zenflows.DB.Page.all()`) into a Relay connection.
"""
@spec from_list([Ecto.Schema.t()], Page.t()) :: t()
def from_list(records, %{cur: cur, num: num}) do
	# Currently, we don't differenciate between forwards or
	# backwards paging, so we only care whether `cur` is nil or
	# not.

	{edges, count} =
		Enum.reduce(records, {[], 0}, fn r, {edges, count} ->
			{[%{cursor: r.id, node: r} | edges], count + 1}
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

	%__MODULE__{
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

@doc """
Parses a Relay-specific map with filters into a generic
`t:Zenflows.DB.Page.t()`.
"""
@spec parse(Schema.params()) :: {:ok, Page.t()} | {:error, Changeset.t()}
def parse(params) do
	with {:ok, data} <- Changeset.apply_action(changeset(params), nil) do
		after_ = data[:after]
		first = data[:first]
		before = data[:before]
		last = data[:last]

		{:ok, %Page{
			dir: if(before || last, do: :back, else: :forw),
			cur: after_ || before,
			num: if((n = first || last), do: normalize(n), else: def_page_size()),
			filter: data[:filter],
		}}
	end
end

@doc false
@spec changeset(Schema.params()) :: Changeset.t()
def changeset(params) do
	{%{}, %{after: ID, first: :integer, before: ID, last: :integer, filter: :map}}
	|> Changeset.cast(params, [:after, :first, :before, :last, :filter])
	|> Changeset.validate_number(:first, greater_than_or_equal_to: 0)
	|> Changeset.validate_number(:last, greater_than_or_equal_to: 0)
	|> Validate.exist_nand([:first, :last])
	|> Validate.exist_nand([:after, :before])
	|> Validate.exist_nand([:after, :last])
	|> Validate.exist_nand([:before, :first])
end

@spec normalize(non_neg_integer()) :: non_neg_integer()
defp normalize(num) do
	# credo:disable-for-next-line Credo.Check.Refactor.MatchInCondition
	if num > (max = max_page_size()),
		do: max, else: num
end

@doc "The default page size for paging."
@spec def_page_size() :: non_neg_integer()
def def_page_size(), do: Keyword.fetch!(conf(), :def_page_size)

@doc "The maximum page size for paging."
@spec max_page_size() :: non_neg_integer()
def max_page_size(), do: Keyword.fetch!(conf(), :max_page_size)

@spec conf() :: Keyword.t()
defp conf(), do: Application.fetch_env!(:zenflows, Zenflows.GQL)
end
