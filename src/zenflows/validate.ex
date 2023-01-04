# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.Validate do
@moduledoc "Ecto.Changeset validation helpers."

alias Ecto.Changeset

require Logger

@typedoc """
Used to specify whether to fetch the field's value from the `:changes`,
`:data`, or `:both` of an `Ecto.Changeset`, respectively.

Basically, uses `Ecto.Changeset.fetch_field/2` behind the scenes,
but `nil` values will mean empty/not-provided.
"""
@type fetch_method() :: :change | :data | :both

@doc """
Escape possible characters that could represent expressions in SQL's
`LIKE` keyword of a field.   The value is changed if it is present.
"""
@spec escape_like(Changeset.t(), atom()) :: Changeset.t()
def escape_like(cset, field) do
	case Changeset.fetch_change(cset, :field) do
		{:ok, v} ->
			v = Regex.replace(~r/\\|%|_/, v, &"\\#{&1}")
			Changeset.put_change(cset, field, v)
		:error -> cset
	end
end

@doc """
Use the OR logic on the existance of `fields`, and error if the
result is false.

Note: `fields` must contain at least 2 items, and make sure to read
`t:fetch_method()`'s doc.
"""
@spec exist_or(Changeset.t(), [atom(), ...], Keyword.t()) :: Changeset.t()
def exist_or(cset, fields, opts \\ []) do
	meth = Keyword.get(opts, :method, :change)
	if Enum.any?(fields, &field_exists?(meth, cset, &1)) do
		cset
	else
		Enum.reduce(fields, cset,
			&Changeset.add_error(&2, &1, "at least one of them must be provided"))
	end
end

@doc """
Use the XOR logic on the existance of `fields`, and error if the
result is false.

Note: `fields` must contain at least 2 items, and make sure to read
`t:fetch_method()`'s doc.
"""
@spec exist_xor(Changeset.t(), [atom(), ...], Keyword.t()) :: Changeset.t()
def exist_xor(cset, [h | t] = fields, opts \\ []) do
	meth = Keyword.get(opts, :method, :change)
	h_exists? = field_exists?(meth, cset, h)

	if Enum.all?(t, &(h_exists? != field_exists?(meth, cset, &1))) do
		cset
	else
		Enum.reduce(fields, cset,
			&Changeset.add_error(&2, &1, "exactly one of them must be provided"))
	end
end

@doc """
Use the NAND logic on the existance of `fields`, and error if the
result is false.

Note: `fields` must contain at least 2 items, and make sure to
read `t:fetch_method()`'s doc.
"""
@spec exist_nand(Changeset.t(), [atom(), ...], Keyword.t()) :: Changeset.t()
def exist_nand(cset, fields, opts \\ []) do
	meth = Keyword.get(opts, :method, :change)
	if Enum.all?(fields, &field_exists?(meth, cset, &1)) do
		Enum.reduce(fields, cset,
			&Changeset.add_error(&2, &1, "one or none of them must be provided"))
	else
		cset
	end
end

@doc """
Compare the values of `fields`, and error if they aren't equal to
each other.

Note: `fields` must contain at least 2 items, and make sure to read
`t:fetch_method()`'s doc.  Also, empty fields will be skipped to
allow more flexibility.  Use `Ecto.Changeset.validate_required/3`
to achieve otherwise.
"""
@spec value_eq(Changeset.t(), [atom(), ...], Keyword.t()) :: Changeset.t()
def value_eq(cset, [a, b], opts \\ []) do
	meth = Keyword.get(opts, :method, :change)
	with {:ok, x} <- field_fetch(meth, cset, a),
			{:ok, y} <- field_fetch(meth, cset, b) do
		if x == y do
			cset
		else
			msg = "all of them must be the same"
			cset
			|> Changeset.add_error(a, msg)
			|> Changeset.add_error(b, msg)
		end
	else _ ->
		cset
	end
end

@doc """
Compare the values of `fields`, and error if they aren't all
different.

Note: `fields` must contain at least 2 items, and make sure to read
`t:fetch_method()`'s doc.  Also, empty fields will be skipped to
allow more flexibility.  Use `Ecto.Changeset.validate_required/3`
to achieve otherwise.
"""
@spec value_ne(Changeset.t(), [atom(), ...], Keyword.t()) :: Changeset.t()
def value_ne(cset, [a, b], opts \\ []) do
	meth = Keyword.get(opts, :method, :change)
	with {:ok, x} <- field_fetch(meth, cset, a),
			{:ok, y} <- field_fetch(meth, cset, b) do
		if x != y do
			cset
		else
			msg = "all of them must be different"
			cset
			|> Changeset.add_error(a, msg)
			|> Changeset.add_error(b, msg)
		end
	else _ ->
		cset
	end
end

@doc "Validate that given `field` is a valid email address."
@spec email(Changeset.t(), atom()) :: Changeset.t()
def email(cset, field) do
	# works good enough for now
	Changeset.validate_format(cset, field, ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/)
end

@doc """
Validate that given `field` is [1, 256] bytes long.

The name "name" is a reference to short texts, as in email subject,
usernames, full names, and so on.
"""
@spec name(Changeset.t(), atom()) :: Changeset.t()
def name(cset, field), do: byte_range(cset, field, 1, 256)

@doc """
Validate that given `field` is [1, 2048] bytes long.

The name "note" is a reference to long texts, as in email bodies,
descriptions, notes, and so on.
"""
@spec note(Changeset.t(), atom()) :: Changeset.t()
def note(cset, field), do: byte_range(cset, field, 1, 2048)

@doc """
Validate that given `field` is [16, 2048] bytes long.

The name "key" is a reference to encoded cryptographic keys (so the
size is not the size of the binary key).
"""
@spec key(Changeset.t(), atom()) :: Changeset.t()
def key(cset, field), do: byte_range(cset, field, 16, 2048)

@doc """
Validate that given `field` is [1, 512] bytes long.

The name "uri" is a reference to not-literal URIs, but a size used
for mostly URIs.
"""
@spec uri(Changeset.t(), atom()) :: Changeset.t()
def uri(cset, field), do: byte_range(cset, field, 1, 512)

@doc """
Validate that given `field` is [1B, 25MiB] long, and log a warning
if it is longer than 4MiB.

The name "img" is a reference to Base64-encoded image binary data.
"""
@spec img(Changeset.t(), atom()) :: Changeset.t()
def img(cset, field) do
	Changeset.validate_change(cset, field, __MODULE__, fn
		_, str when byte_size(str) < 1 ->
			[{field, "should be at least 1B long"}]
		_, str when byte_size(str) > 25 * 1024 * 1024 ->
			[{field, "should be at most 25MiB long"}]
		_, str when byte_size(str) > 4 * 1024 * 1024 ->
			Logger.warning("file exceeds 4MiB")
			[]
		_, _ ->
			[]
	end)
end

@doc """
Validate that given `field` is a list of binaries, which are [1,
512] bytes long in size, and the list itself contains [1, 128]
items.

The name "class" is a reference to list of strings used for tagging,
categorization and so on.
"""
@spec class(Changeset.t(), atom()) :: Changeset.t()
def class(cset, field) do
	Changeset.validate_change(cset, field, __MODULE__, fn
		_, [] ->
			[{field, "must contain at least 1 item"}]
		_, list ->
			case do_class(list, 0, 128) do
				{:exceeds, _ind} ->
					[{field, "must contain at most 128 items"}]
				{:short, ind} ->
					[{field, "the item at #{ind + 1} cannot be shorter than 1 byte"}]
				{:long, ind} ->
					[{field, "the item at #{ind + 1} cannot be longer than 512 bytes"}]
				{:valid, _ind} ->
					[]
			end
	end)
end

# The rationale of this function is to loop over the list while
# decreasing `rem` (reminder) and increasing `ind` (index) until
# either one of these happen (in that order):
#
#      1. `rem` is equal to 0
#      2. one of the items in the list is shorter than 1 byte long
#      3. one of the items in the list is longer than 512 bytes long
#
@spec do_class([String.t()], non_neg_integer(), non_neg_integer())
	:: {:exceeds | :short | :long | :valid, non_neg_integer()}
defp do_class([], ind, _), do: {:valid, ind - 1}
defp do_class([h | t], ind, rem) do
	cond do
		rem == 0 -> {:exceeds, ind}
		byte_size(h) < 1 -> {:short, ind}
		byte_size(h) > 512 -> {:long, ind}
		true -> do_class(t, ind + 1, rem - 1)
	end
end

@doc """
Validate that the given binary (in Elixir terms) is in this inclusive
octects/bytes range.
"""
@spec byte_range(Changeset.t(), atom(), non_neg_integer(), non_neg_integer())
	:: Changeset.t()
def byte_range(cset, field, min, max) do
	Changeset.validate_change(cset, field, __MODULE__, fn
		_, bin when byte_size(bin) < min ->
			[{field, "should be at least #{min} byte(s) long"}]
		_, bin when byte_size(bin) > max ->
			[{field, "should be at most #{max} byte(s) long"}]
		_, _ ->
			[]
	end)
end

@spec field_exists?(fetch_method(), Changeset.t(), atom()) :: boolean()
defp field_exists?(:change, cset, field) do
	case Changeset.fetch_field(cset, field) do
		{:changes, x} when not is_nil(x) -> true
		_ -> false
	end
end
defp field_exists?(:data, cset, field) do
	case Changeset.fetch_field(cset, field) do
		{:data, x} when not is_nil(x) -> true
		_ -> false
	end
end
defp field_exists?(:both, cset, field) do
	case Changeset.fetch_field(cset, field) do
		{:changes, x} when not is_nil(x) -> true
		{:data, x} when not is_nil(x) -> true
		_ -> false
	end
end

@spec field_fetch(fetch_method(), Changeset.t(), atom()) :: {:ok, term()} | :error
defp field_fetch(:change, cset, field) do
	case  Changeset.fetch_field(cset, field) do
		{:changes, v} -> {:ok, v}
		_ -> :error
	end
end
defp field_fetch(:data, cset, field) do
	case  Changeset.fetch_field(cset, field) do
		{:data, v} -> {:ok, v}
		_ -> :error
	end
end
defp field_fetch(:both, cset, field) do
	case Changeset.fetch_field(cset, field) do
		:error -> :error
		{_, v} -> {:ok, v}
	end
end
end
