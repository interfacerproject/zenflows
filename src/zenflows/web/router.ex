defmodule Zenflows.Web.Router do
@moduledoc "Plug entrypoint/router."

use Plug.Router

alias Zenflows.Web.MW

plug :match
plug Plug.RequestId
plug Plug.Logger
plug Plug.Parsers,
	parsers: [{:json, json_decoder: Jason}, Absinthe.Plug.Parser],
	pass: ["*/*"],
	body_reader: {__MODULE__, :read_body, []}
plug MW.GQLContext
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

@doc false
def read_body(conn, opts) do
	alias Plug.Conn

	case Conn.read_body(conn, opts) do
		{:ok, data, conn} ->
			conn = Conn.assign(conn, :raw_body, data)
			{:ok, data, conn}
		{:more, data, conn} ->
			# Since it'll fail due to too large body, we don't
			# need to assign.
			{:more, data, conn}
		{:error, reason} ->
			{:error, reason}
	end
end
end
