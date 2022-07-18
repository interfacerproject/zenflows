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
	end
end
end
