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

defmodule Zenflows.Web.MW.GQLContext do
@moduledoc """
Plug middleware to set Absinthe context.

Must be placed after `Plug.Parsers`.
"""

@behaviour Plug

alias Plug.Conn

@impl true
def init(opts), do: opts

@impl true
def call(conn, _opts) do
	ctx =
		%{}
		|> set_admin(conn)
		|> set_user_and_sign_and_body(conn)

	Absinthe.Plug.put_options(conn, context: ctx)
end

# Set `admin` key from the headers.
@spec set_admin(map(), Conn.t()) :: map()
defp set_admin(ctx, conn) do
	case Conn.get_req_header(conn, "zenflows-admin") do
		[key | _] -> Map.put(ctx, :gql_admin, key)
		_ -> ctx
	end
end

# Set `user` and `sign` keys from the headers, and `body` key from
# `conn.assigs`, if only `admin` is not set.
@spec set_user_and_sign_and_body(map(), Conn.t()) :: map()
defp set_user_and_sign_and_body(%{gql_admin: _} = ctx, _conn), do: ctx
defp set_user_and_sign_and_body(ctx, conn) do
	with [user | _] <- Conn.get_req_header(conn, "zenflows-user"),
			[sign | _] <- Conn.get_req_header(conn, "zenflows-sign"),
			{:ok, raw_body} <- Map.fetch(conn.assigns, :raw_body) do
		ctx
		|> Map.put(:gql_user, user)
		|> Map.put(:gql_sign, sign)
		|> Map.put(:gql_body, raw_body)
	else _ ->
		ctx
	end
end
end
