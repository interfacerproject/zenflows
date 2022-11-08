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

defmodule Zenflows.DB.Page do
@moduledoc "Paging utilities to page results."

import Ecto.Query

alias Zenflows.DB.{ID, Repo}

@enforce_keys ~w[dir cur num filter]a
defstruct [:cur, :num, :filter, dir: :forw]

@typedoc """
Represents a generic struct that has all required information to
(possibly filter and) paginate the rows of the database.

The fields are:
* `dir` - represents the *direction* that the database should query.
* `cur` - represents the *cursor* handle to use to paginate.
* `num` - represents the *number* of rows (+1) to fetch.
* `filter` - represents the filters to be used for querying.
"""

@type t() :: %__MODULE__{
	dir: :forw | :back,
	cur: nil | ID.t(),
	num: non_neg_integer(),
	filter: nil | map(),
}

@doc """
Parses a half-baked map/keyword into a `t:t()`.

You should use this function for functions that expect `t:t()`, and
you don't have any other means to generate a `t:t()` (such as with
`Zenflows.GQL.Connection.parse/2` that converts Relay-specific
paging information into `t:t()`).
"""
@spec new(map() | Keyword.t()) :: t()
def new(_ \\ %{})
def new(params) when is_list(params), do: Map.new(params) |> new()
def new(params) when is_map(params) do
	%__MODULE__{
		dir: params[:dir] || :forw,
		cur: params[:cur],
		num: params[:num] || Zenflows.GQL.Connection.def_page_size(),
		filter: params[:filter],
	}
end

@doc """
Similar to `c:Ecto.Repo.all/2`, but the result is paginated.

Basically, transforms the queryable `q` into another query that
limits the amount of returned records according to `dir`, `cur` and
`num` (read `t:t()` on what those variables are used for).
"""
@spec all(Ecto.Queryable.t(), t()) :: [Ecto.Schema.t()]
def all(q, %{dir: dir, cur: cur, num: num}) do
	order_by =
		case dir do
			:forw -> [asc: :id]
			:back -> [desc: :id]
		end
	where =
		case {dir, cur} do
			{_, nil} -> []
			{:forw, cur} -> dynamic([x], x.id > ^cur)
			{:back, cur} -> dynamic([x], x.id < ^cur)
		end
	from(x in q,
		where: ^where,
		order_by: ^order_by,
		limit: ^num + 1,
		select: x)
	|> Repo.all()
end
end
