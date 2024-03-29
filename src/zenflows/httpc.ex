# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.HTTPC do
@moduledoc """
An HTTP client implemented for Zenswarm, Restroom, and Sendgrid.
"""
use GenServer

require Logger

alias Mint.HTTP

@type state() :: %__MODULE__{
	conn: Mint.HTTP.t(),
	conn_info: {
		Mint.Types.scheme(),
		Mint.Types.address(),
		:inet.port_number(),
	},
	requests: %{
		Mint.Types.request_ref() => %{
			from: GenServer.from(),
			response: %{
				status: Mint.Types.status(),
				headers: Mint.Types.headers(),
				data: binary(),
				error: term(),
			},
		},
	},
}

defstruct [:conn, conn_info: {}, requests: %{}]

def start_link(opts) do
	scheme = Keyword.fetch!(opts, :scheme)
	host = Keyword.fetch!(opts, :host)
	port = Keyword.fetch!(opts, :port)
	name = Keyword.fetch!(opts, :name)
	GenServer.start_link(__MODULE__, {scheme, host, port}, name: name)
end

@spec request(atom(), String.t(), String.t(), Mint.Types.headers())
	:: {:ok, %{status: non_neg_integer(), data: binary(), headers: Mint.Types.headers()}}
		| {:error, term()}
def request(name, method, path, headers \\ [], body \\ nil, max \\ 5) do
	headers =
		case :lists.keyfind("user-agent", 1, headers) do
			{"user-agent", _} -> headers
			false -> [{"user-agent", "zenflows/#{Application.spec(:zenflows, :vsn)}"} | headers]
		end
	Enum.reduce_while(1..max, nil, fn x, _ ->
		case GenServer.call(name, {:request, method, path, headers, body}) do
			{:ok, result} ->
				{:halt, {:ok, result}}
			{:error_conn, reason} ->
				if x != max, do: Process.sleep(5)
				{:cont, {:error, reason}}
			{:error_req, reason} ->
				{:halt, {:error, reason}}
		end
	end)
end

@impl true
def init({scheme, host, port}) do
	{:ok, %__MODULE__{conn_info: {scheme, host, port}}}
end

@impl true
def handle_call({:request, method, path, headers, body}, from, state) do
	if state.conn && HTTP.open?(state.conn) do
		{:ok, state}
	else
		{scheme, host, port} = state.conn_info
		case HTTP.connect(scheme, host, port) do
			{:ok, conn} ->
				state = put_in(state.conn, conn)
				{:ok, state}
			{:error, reason} ->
				{:error, reason}
		end
	end
	|> case do
		{:ok, state} ->
			case HTTP.request(state.conn, method, path, headers, body) do
				{:ok, conn, request_ref} ->
					state = put_in(state.conn, conn)
					state = put_in(state.requests[request_ref], %{from: from, response: %{}})
					{:noreply, state}

				{:error, conn, reason} ->
					state = put_in(state.conn, conn)
					{:reply, {:error_req, reason}, state}
			end
		{:error, reason} ->
			{:reply, {:error_conn, reason}, state}
	end
end

@impl true
def handle_info(message, state) do
	case HTTP.stream(state.conn, message) do
		:unknown ->
			Logger.error("Received unknown message: #{inspect(message)}")
			{:noreply, state}

		{:ok, conn, responses} ->
			state = put_in(state.conn, conn)
			state = Enum.reduce(responses, state, &process_response/2)

			{:noreply, state}
		{:error, conn, _reason, responses} ->
			state = put_in(state.conn, conn)
			# Send a response to all the succesful request
			state = Enum.reduce(responses, state, &process_response/2)

			{:noreply, state}
	end
end

@spec process_response({:status, Mint.Types.request_ref(), Mint.Types.status()}
	| {:headers, Mint.Types.request_ref(), Mint.Types.headers()}
	| {:data, Mint.Types.request_ref(), binary()}
	| {:done, Mint.Types.request_ref()}
	| {:error, Mint.Types.request_ref(), term()}, state()) :: state()
defp process_response({:status, request_ref, status}, state) do
	put_in(state.requests[request_ref].response[:status], status)
end

defp process_response({:headers, request_ref, headers}, state) do
	put_in(state.requests[request_ref].response[:headers], headers)
end

defp process_response({:data, request_ref, new_data}, state) do
	update_in(state.requests[request_ref].response[:data], fn data -> [data || "", new_data] end)
end

defp process_response({:error, request_ref, error}, state) do
	update_in(state.requests[request_ref].response[:error], error)
end

defp process_response({:done, request_ref}, state) do
	state = update_in(state.requests[request_ref].response[:data], fn
		nil -> ""
		x -> IO.iodata_to_binary(x)
	end)
	{%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
	GenServer.reply(from, {:ok, response})
	state
end
end
