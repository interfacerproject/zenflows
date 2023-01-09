defmodule Zenflows.HTTPC do
@moduledoc """
An HTTP client implemented for Zenswarm and Restroom.
"""
use GenServer

require Logger

alias Mint.HTTP

defstruct [:conn, conn_info: {}, requests: %{}]

def start_link(opts) do
	scheme = Keyword.fetch!(opts, :scheme)
	host = Keyword.fetch!(opts, :host)
	port = Keyword.fetch!(opts, :port)
	name = Keyword.fetch!(opts, :name)
	GenServer.start_link(__MODULE__, {scheme, host, port}, name: name)
end

@spec request(term(), term(), term(), term())
	:: {:ok, term()} | {:error, term()}
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
			_ = Logger.error(fn -> "Received unknown message: " <> inspect(message) end)
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

defp process_response({:status, request_ref, status}, state) do
	put_in(state.requests[request_ref].response[:status], status)
end

defp process_response({:headers, request_ref, headers}, state) do
	put_in(state.requests[request_ref].response[:headers], headers)
end

defp process_response({:data, request_ref, new_data}, state) do
	update_in(state.requests[request_ref].response[:data], fn data -> [(data || ""), new_data] end)
end

defp process_response({:error, request_ref, error}, state) do
	update_in(state.requests[request_ref].response[:error], error)
end

defp process_response({:done, request_ref}, state) do
	state = update_in(state.requests[request_ref].response[:data], &IO.iodata_to_binary/1)
	{%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
	GenServer.reply(from, {:ok, response})
	state
end
end
