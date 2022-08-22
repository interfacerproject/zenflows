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

defmodule ZenflowsTest.GQL.Paging do
use ZenflowsTest.Help.EctoCase, async: true

# What we are testing here is a bit interesting.  Because, you see,
# what we actually care about is dependant on the number of records we
# ask for (referred to by "num" from now on).  This is because of we
# always try to fetch num+1 records.  This basically means that we'll
# have a table of possible cases:
#
# num | len(edges)
# ----+-----------
# 0   | 0
# 0   | 1
# ----+-----------
# 1   | 0
# 1   | 1
# 1   | 2
# ----+-----------
# 2   | 0
# 2   | 1
# 2   | 2
# 2   | 3
# ----+-----------
# 3   | 0
# 3   | 1
# 3   | 2
# 3   | 3
# 3   | 4
# ----+-----------
# 4   | 0
# 4   | 1
# 4   | 2
# 4   | 3
# 4   | 4
# 4   | 5

# Here, we cover the cases of:
# num | len(edges)
# ----+-----------
# 0   | 0
# 1   | 0
# 2   | 0
# 3   | 0
# 4   | 0
test "num>=0 && len(edges)==0:" do
	Enum.each(0..10, fn n ->
		assert %{data: %{"people" => data}} =
			run!("""
				query ($n: Int!) {
					people (first: $n) {...people}
				}
			""", vars: %{"n" => n})

		assert [] = Map.fetch!(data, "edges")

		assert %{
			"startCursor" => nil,
			"endCursor" => nil,
			"hasPreviousPage" => false,
			"hasNextPage" => false,
			"totalCount" => 0,
			"pageLimit" => ^n,
		} = Map.fetch!(data, "pageInfo")
	end)
end

# Here, we cover the cases of:
# num | len(edges)
# ----+-----------
# 1   | 1
# 2   | 2
# 3   | 3
# 4   | 4
test "num>=1 && len(edges)==num:" do
	Enum.reduce(1..10, [], fn n, pers ->
		last = %{id: last_cur} = Factory.insert!(:person)
		pers = pers ++ [last]
		[%{id: first_cur} | _] = pers

		assert %{data: %{"people" => data}} =
			run!("""
				query ($n: Int!) {
					people (first: $n) {...people}
				}
			""", vars: %{"n" => n})

		edges = Map.fetch!(data, "edges")
		assert length(edges) == n

		assert %{
			"startCursor" => ^first_cur,
			"endCursor" => ^last_cur,
			"hasPreviousPage" => false,
			"hasNextPage" => false,
			"totalCount" => ^n,
			"pageLimit" => ^n,
		} = Map.fetch!(data, "pageInfo")

		pers
	end)
end

# Here, we cover the cases of:
# num | len(edges)
# ----+-----------
# 0   | 1
# 1   | 2
# 2   | 3
# 3   | 4
# 4   | 5
test "num>=0 && len(edges)==num+1:" do
	Enum.reduce(0..10, [], fn n, pers ->
		pers = pers ++ [Factory.insert!(:person)]
		{tmp, _} = Enum.split(pers, n)
		first = List.first(tmp)
		last = List.last(tmp)
		first_cur = if first != nil, do: first.id, else: nil
		last_cur = if last != nil, do: last.id, else: nil

		assert %{data: %{"people" => data}} =
			run!("""
				query ($n: Int!) {
					people (first: $n) {...people}
				}
			""", vars: %{"n" => n})

		edges = Map.fetch!(data, "edges")
		assert length(edges) == n

		assert %{
			"startCursor" => ^first_cur,
			"endCursor" => ^last_cur,
			"hasPreviousPage" => false,
			"hasNextPage" => true,
			"totalCount" => ^n,
			"pageLimit" => ^n,
		} = Map.fetch!(data, "pageInfo")

		pers
	end)
end

# Here, we cover the last case, which prooves we cover all the cases
# (this is so because of the fact that we only deal with len(edges)<num
# cases, where num>=1):
# num | len(edges)
# ----+-----------
# 2   | 1
# ----+-----------
# 3   | 1
# 3   | 2
# ----+-----------
# 4   | 1
# 4   | 2
# 4   | 3
test "num>=2 && len(edges)>=0 && len(edges)<num:" do
	Enum.reduce(1..9, [], fn e, pers ->
		pers = pers ++ [Factory.insert!(:person)]

		Enum.each(2..10, fn n ->
			if e < n do
				assert %{data: %{"people" => data}} =
					run!("""
						query ($n: Int!) {
							people (first: $n) {...people}
						}
					""", vars: %{"n" => n})

				edges = Map.fetch!(data, "edges")
				assert length(edges) == e

				%{id: first_cur} = List.first(pers)
				%{id: last_cur} = List.last(pers)

				assert %{
					"startCursor" => ^first_cur,
					"endCursor" => ^last_cur,
					"hasPreviousPage" => false,
					"hasNextPage" => false,
					"totalCount" => ^e,
					"pageLimit" => ^n,
				} = Map.fetch!(data, "pageInfo")
			end
		end)

		pers
	end)
end

# We're dealing with cursors here now.  Most of the cases are the
# same as the ones without the cursors, so we omit them.

# Here, we cover the cases of:
# num | len(edges)
# ----+-----------
# 1   | 1
# 2   | 2
# 3   | 3
# 4   | 4
test "with cursor: num>=1 && len(edges)==num:" do
	Enum.each(1..10, fn n ->
		p = Factory.insert!(:person)

		assert %{data: %{"people" => data}} =
			run!("""
				query ($cur: ID! $n: Int!) {
					people (after: $cur first: $n) {...people}
				}
			""", vars: %{"n" => n, "cur" => p.id})

		assert [] = Map.fetch!(data, "edges")

		assert %{
			"startCursor" => nil,
			"endCursor" => nil,
			"hasPreviousPage" => true, # spec says so if we can't determine
			"hasNextPage" => false,
			"totalCount" => 0,
			"pageLimit" => ^n,
		} = Map.fetch!(data, "pageInfo")
	end)
end

# Here, we cover the cases of:
# num | len(edges)
# ----+-----------
# 1   | 2
# 2   | 3
# 3   | 4
# 4   | 5
test "with cursor: num>=1 && len(edges)==num+1:" do
	pers = [Factory.insert!(:person)]
	Enum.reduce(1..10, pers, fn n, pers ->
		%{id: after_cur} = List.last(pers)
		last = %{id: last_cur} = Factory.insert!(:person)
		pers = pers ++ [last]

		assert %{data: %{"people" => data}} =
			run!("""
				query ($cur: ID! $n: Int!) {
					people (after: $cur first: $n) {...people}
				}
			""", vars: %{"n" => n, "cur" => after_cur})

		assert [_] = Map.fetch!(data, "edges")

		assert %{
			"startCursor" => ^last_cur,
			"endCursor" => ^last_cur,
			"hasPreviousPage" => true, # spec
			"hasNextPage" => false,
			"totalCount" => 1,
			"pageLimit" => ^n,
		} = Map.fetch!(data, "pageInfo")

		pers
	end)
end

@spec run!(String.t(), Keyword.t()) :: Absinthe.run_result()
def run!(doc, opts \\ []) do
	"""
	#{doc}
	fragment people on PersonConnection {
		pageInfo {
			startCursor
			endCursor
			hasPreviousPage
			hasNextPage
			totalCount
			pageLimit
		}
		edges {
			cursor
			node {id}
		}
	}
	"""
	|> ZenflowsTest.Help.AbsinCase.run!(opts)
end
end
