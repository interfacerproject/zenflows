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

defmodule Zenflows.VF.Validate do
@moduledoc """
Common Valueflows validators for Ecto.Changesets.  All the limitations
here are rough and can be changed in the future.
"""

alias Ecto.Changeset, as: Chset

require Logger

@doc "Checks if the given string field is [16, 2048] bytes long."
@spec key(Chset.t(), atom()) :: Chset.t()
def key(cset, field) do
	Chset.validate_change(cset, field, :valflow, fn
		_, str when byte_size(str) < 16 ->
			[{field, "should be at least 16 bytes long"}]
		_, str when byte_size(str) > 2048 ->
			[{field, "should be at most 2048 bytes long"}]
		_, _ ->
			[]
	end)
end

@doc "Checks if the given string field is [2, 256] bytes long."
@spec name(Chset.t(), atom()) :: Chset.t()
def name(cset, field) do
	Chset.validate_change(cset, field, :valflow, fn
		_, str when byte_size(str) < 2 ->
			[{field, "should be at least 2 bytes long"}]
		_, str when byte_size(str) > 256 ->
			[{field, "should be at most 256 bytes long"}]
		_, _ ->
			[]
	end)
end

@doc "Checks if the given string field is [2, 2048] bytes long."
@spec note(Chset.t(), atom()) :: Chset.t()
def note(cset, field) do
	Chset.validate_change(cset, field, :valflow, fn
		_, str when byte_size(str) < 2 ->
			[{field, "should be at least 2 bytes long"}]
		_, str when byte_size(str) > 2048 ->
			[{field, "should be at most 2048 bytes long"}]
		_, _ ->
			[]
	end)
end

@doc "Checks if the given string is [3, 512] bytes long."
@spec uri(Chset.t(), atom()) :: Chset.t()
def uri(cset, field) do
	Chset.validate_change(cset, field, :valflow, fn
		_, str when byte_size(str) < 3 ->
			[{field, "should be at least 3 bytes long"}]
		_, str when byte_size(str) > 512 ->
			[{field, "should be at most 512 bytes long"}]
		_, _ ->
			[]
	end)
end

@mebibyte 1024**2

@doc """
Check if the given base64-encoded binary data is at least 1B, at most
25MiB in size.  And, display a warning if it is longer than 4MiB.
"""
@spec img(Chset.t(), atom()) :: Chset.t()
def img(cset, field) do
	Chset.validate_change(cset, field, :valflow, fn
		_, str when byte_size(str) < 1 ->
			[{field, "should be at least 1B long"}]
		_, str when byte_size(str) > 25 * @mebibyte ->
			[{field, "should be at most 25MiB long"}]
		_, str when byte_size(str) > 4 * @mebibyte ->
			Logger.warning("file exceeds 4MiB")
			[]
		_, _ ->
			[]
	end)
end

@doc """
Checks if the given classifications (list of strings) for:

	- Each item in the list is [3, 512] bytes long;
	- The list can contain only [1, 128] items.
"""
@spec class(Chset.t(), atom()) :: Chset.t()
def class(cset, field) do
	Chset.validate_change(cset, field, :valflow, fn
		_, [] ->
			[{field, "must contain at least 1 item"}]
		_, list ->
			case do_class(list) do
				{:exceeds, _ind} -> [{field, "must contain at most 128 items"}]
				{:short, ind} -> [{field, "the item at #{ind + 1} cannot be shorter than 3 bytes"}]
				{:long, ind} -> [{field, "the item at #{ind + 1} cannot be longer than 512 bytes"}]
				{:valid, _ind} -> []
			end
	end)
end

@spec do_class([String.t()]) :: {atom(), integer()}
defp do_class(list) do
	do_class(list, 0, 128)
end

# The rationale of this function is to loop over the list while decreasing
# `remaining' and increasing `index' until either one of these happen (in
# that order):
#     * remaining hits 0
#     * one of the items in the list is shorter than 3 bytes long
#     * one of the items in the list is longer than 512 bytes long
@spec do_class([String.t()], integer(), integer()) :: {atom(), integer()}
defp do_class([head | tail], index, remaining) do
	cond do
		remaining == 0 -> {:exceeds, index}
		byte_size(head) < 3 -> {:short, index}
		byte_size(head) > 512 -> {:long, index}
		true -> do_class(tail, index + 1, remaining - 1)
	end
end

defp do_class([], index, _) do
	{:valid, index - 1}
end
end
