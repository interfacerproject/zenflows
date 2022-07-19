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

# TODO: Decide whether we really want these to be valid URIs or just
# Strings.
@spec uri_parse(Input.t()) :: {:ok, String.t() | nil} | :error
defp uri_parse(%Input.String{value: v}), do: {:ok, v}
defp uri_parse(%Input.Null{}), do: {:ok, nil}
defp uri_parse(_), do: :error

@spec id_parse(Input.t()) :: {:ok, ID.t() | nil} | :error
def id_parse(%Input.String{value: v}), do: ID.cast(v)
def id_parse(%Input.Null{}), do: {:ok, nil}
def id_parse(_), do: :error
end
