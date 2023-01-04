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

@init_opts [schema: Zenflows.GQL.Schema]

forward "/api/file",
	to: Zenflows.Web.File

forward "/api",
	to: Absinthe.Plug,
	init_opts: @init_opts

forward "/play",
	to: Absinthe.Plug.GraphiQL,
	init_opts: [{:interface, :advanced} | @init_opts]

@sdl Absinthe.Schema.to_sdl(Zenflows.GQL.Schema)
get "/schema" do
	Plug.Conn.send_resp(conn, 200, @sdl)
end

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
