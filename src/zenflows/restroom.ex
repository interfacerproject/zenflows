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

defmodule Zenflows.Restroom do
@moduledoc """
A module to interact with Restroom instances over (for now) HTTP.
"""

def child_spec(_) do
		Supervisor.child_spec(
			{Zenflows.HTTPC,
				name: __MODULE__,
				scheme: :http,
				host: host(),
				port: port(),
			},
			id: __MODULE__)
end

@doc """
Returns `true` when `left` and `right` are equal, `false` otherwise.
"""
@spec byte_equal?(binary(), binary()) :: boolean()
def byte_equal?(left, right) do
	data = %{left: Base.encode64(left), right: Base.encode64(right)}
	case exec("byte_equal", data) do
		{:ok, %{"output" => ["1"]}} -> true
		_ -> false
	end
end

@doc """
Given the GraphQL `body`, its `signature`, and `pubkey` of the user who
executes the query, verify that everything matches.
"""
@spec verify_graphql(binary(), String.t(), String.t()) :: :ok | {:error, String.t()}
def verify_graphql(body, signature, pubkey) do
	data = %{
		"gql" => Base.encode64(body),
		"eddsa_signature" => signature,
		"eddsa_public_key" => pubkey,
	}
	case exec("verify_graphql", data) do
		{:ok, %{"output" => ["1"]}} -> :ok
		{:error, reason} -> {:error, reason}
	end
end

@doc """
See https://github.com/dyne/keypairoom for details.
"""
@spec keypairoom_server(map()) :: {:ok, String.t()} | {:error, term()}
def keypairoom_server(data) do
	data = %{
		"userData" => data,
		"serverSideSalt" => salt(),
	}
	case exec("keypairoomServer-6-7", data) do
		{:ok, %{"seedServerSideShard.HMAC" => hmac}} -> {:ok, hmac}
		{:error, reason} -> {:error, reason}
	end
end

# Execute a Zencode specified by `name` with JSON data `data`.
@spec exec(String.t(), map()) :: {:ok, map()} | {:error, term()}
defp exec(name, post_data) do
	hdrs = [{"content-type", "application/json"}]

	with {:ok, post_body} <- Jason.encode(%{data: post_data}),
			{:ok, %{status: stat, data: body}} when stat == 200 or stat == 500 <-
				request("POST", "/api/#{name}", hdrs, post_body),
			{:ok, data} <- Jason.decode(body) do
		if stat == 200 do
			{:ok, data}
		else
			{:error, data |> Map.fetch!("zenroom_errors") |> Map.fetch!("logs")}
		end
	else
		{:ok, %{status: stat, data: body}} ->
			{:error, "the http call result in non-200 status code #{stat}: #{inspect(body)}"}

		other -> other
	end
end

defp request(method, path, headers, body) do
	Zenflows.HTTPC.request(__MODULE__, method, path, headers, body)
end

# Return the salt from the configs.
@spec salt() :: String.t()
defp salt() do
	Keyword.fetch!(conf(), :room_salt)
end

# Return the hostname of restroom from the configs.
@spec host() :: String.t()
defp host() do
	Keyword.fetch!(conf(), :room_host)
end

# Return the port of restroom from the configs.
@spec port() :: non_neg_integer()
defp port() do
	Keyword.fetch!(conf(), :room_port)
end

# Return the application configurations of this module.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, __MODULE__)
end
end
