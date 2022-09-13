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

defmodule Zenflows.GQL.Type do
@moduledoc "Custom types or overrides for Absinthe."

use Absinthe.Schema.Notation

alias Absinthe.Blueprint.Input
alias Zenflows.DB.ID

@desc "A [Unified Resource Identity](https://w.wiki/4W2Y) as String."
scalar :uri, name: "URI" do
	parse &uri_parse/1
	serialize & &1
end

@desc "A base64-encoded (requires padding and ignores whitespace) as String."
scalar :base64, name: "Base64" do
	parse &base64_parse/1
	serialize & &1
end

@desc "A base64url-encoded (requires nonpadding and ignores whitespace) as String."
scalar :url64, name: "Url64" do
	parse &url64_parse/1
	serialize & &1
end

@desc "A JSON document encoded as string."
scalar :json, name: "JSON" do
	parse &Jason.decode/1
	serialize & &1
end

@desc "Cursors for pagination"
object :page_info do
	@desc """
	Cursor pointing to the first of the results returned, to be
	used with `before` query parameter if the backend supports
	reverse pagination.
	"""
	field :start_cursor, :id

	@desc """
	Cursor pointing to the last of the results returned, to be used
	with `after` query parameter if the backend supports forward
	pagination.
	"""
	field :end_cursor, :id

	@desc """
	True if there are more results before `startCursor`.  If unable
	to be determined, implementations should return `true` to allow
	for requerying.
	"""
	field :has_previous_page, non_null(:boolean)

	@desc """
	True if there are more results after `endCursor`.  If unable
	to be determined, implementations should return `true` to allow
	for requerying.
	"""
	field :has_next_page, non_null(:boolean)

	@desc "The total result count, if it can be determined."
	field :total_count, :integer

	@desc """
	The number of items requested per page.  Allows the storage
	backend to indicate this when it is responsible for setting a
	default and the client does not provide it.  Note this may be
	different to the number of items returned, if there is less than
	1 page of results.
	"""
	field :page_limit, :integer
end

# TODO: Decide whether we really want these to be valid URIs or just
# Strings.
@spec uri_parse(Input.t()) :: {:ok, String.t() | nil} | :error
defp uri_parse(%Input.String{value: v}), do: {:ok, v}
defp uri_parse(%Input.Null{}), do: {:ok, nil}
defp uri_parse(_), do: :error

@spec base64_parse(Input.t()) :: {:ok, String.t() | nil} | :error
defp base64_parse(%Input.String{value: v}) do
	case Base.decode64(v, ignore: :whitespace, padding: true) do
		{:ok, _} -> {:ok, v}
		:error -> :error
	end
end
defp base64_parse(%Input.Null{}), do: {:ok, nil}
defp base64_parse(_), do: :error

@spec url64_parse(Input.t()) :: {:ok, String.t() | nil} | :error
defp url64_parse(%Input.String{value: v}) do
	case Base.url_decode64(v, ignore: :whitespace, padding: false) do
		{:ok, _} -> {:ok, v}
		:error -> :error
	end
end
defp url64_parse(%Input.Null{}), do: {:ok, nil}
defp url64_parse(_), do: :error

@spec id_parse(Input.t()) :: {:ok, ID.t() | nil} | :error
def id_parse(%Input.String{value: v}), do: ID.cast(v)
def id_parse(%Input.Null{}), do: {:ok, nil}
def id_parse(_), do: :error
end
