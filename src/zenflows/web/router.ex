defmodule Zenflows.Web.Router do
@moduledoc "Plug entrypoint/router."

use Plug.Router

plug :match
plug Plug.RequestId
plug Plug.Logger
plug Plug.Parsers,
	parsers: [:json, Absinthe.Plug.Parser],
	pass: ["*/*"],
	json_decoder: Jason
plug :gql_context
plug :dispatch

forward "/api",
	to: Absinthe.Plug,
	schema: Zenflows.GQL.Schema

forward "/play",
	to: Absinthe.Plug.GraphiQL,
	schema: Zenflows.GQL.Schema,
	interface: :advanced

match _ do
	conn
	|> put_resp_content_type("text/html")
	|> send_resp(404, """
		<a href="/play">go to the playground</a><br/>
		<a href="/api">the api location</a>
	""")
end

# Set the absinthe context with the data fetched from various headers.
defp gql_context(conn, _opts) do
	ctx =
		case get_req_header(conn, "zenflows-admin") do
			[key | _] ->
				%{gql_admin: key}
			_ ->
				with [user | _] <- get_req_header(conn, "zenflows-user"),
						[sign | _] <- get_req_header(conn, "zenflows-sign") do
					%{gql_user: user, gql_sign: sign}
				else _ ->
					%{}
				end
		end

	Absinthe.Plug.put_options(conn, context: ctx)
end
end
