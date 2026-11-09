# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2026 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule ZenflowsTest.HTTPC do
use ExUnit.Case, async: true

alias Zenflows.HTTPC

# Answers after a short pause and closes the connection after every response,
# like a keep-alive timeout or a `connection: close` server.
defmodule ClosingPlug do
	@behaviour Plug

	@impl true
	def init(opts), do: opts

	@impl true
	def call(conn, _opts) do
		Process.sleep(20)
		conn
		|> Plug.Conn.put_resp_header("connection", "close")
		|> Plug.Conn.send_resp(200, conn.request_path)
	end
end

setup do
	ref = :"httpc_test_#{System.unique_integer([:positive])}"
	{:ok, _} = Plug.Cowboy.http(ClosingPlug, [], ref: ref, port: 0)
	port = :ranch.get_port(ref)
	name = :"#{ref}_client"
	start_supervised!({HTTPC, scheme: :http, host: "localhost", port: port, name: name})
	on_exit(fn -> Plug.Cowboy.shutdown(ref) end)
	%{name: name}
end

test "concurrent callers all get their own answer when the server closes connections", %{name: name} do
	results =
		1..10
		|> Enum.map(fn i -> Task.async(fn -> HTTPC.request(name, "GET", "/#{i}") end) end)
		|> Task.await_many(4_000)

	for {result, i} <- Enum.with_index(results, 1) do
		assert {:ok, %{status: 200, data: data}} = result
		assert data == "/#{i}"
	end
end

test "a request after the server closed the connection reconnects", %{name: name} do
	assert {:ok, %{data: "/a"}} = HTTPC.request(name, "GET", "/a")
	assert {:ok, %{data: "/b"}} = HTTPC.request(name, "GET", "/b")
end
end
