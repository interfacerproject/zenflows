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

defmodule Zenflows.Restroom do
@moduledoc """
A module to interact with Restroom instances over (for now) HTTP.
"""

def child_spec(_) do
	Supervisor.child_spec(
		{Zenflows.HTTPC,
			name: __MODULE__,
			scheme: scheme(),
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
@spec verify_graphql(binary(), String.t(), String.t()) :: :ok | {:error, term()}
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
	data = %{"userData" => data, "serverSideSalt" => salt()}
	case exec("keypairoomServer-6-7", data) do
		{:ok, %{"seedServerSideShard.HMAC" => hmac}} -> {:ok, hmac}
		{:error, reason} -> {:error, reason}
	end
end

@doc """
Generate the HMAC (SHA256) signature of `data` using the server-side key.

The returned value in the ok-tuble, `data`, and `key` are base64-encoded
strings.
"""
@spec hmac_new(String.t()) :: {:ok, String.t()} | {:error, term()}
def hmac_new(data) do
	case exec("hmac_new", %{"data" => data, "key" => salt()}) do
		{:ok, %{"HMAC" => sign}} -> {:ok, sign}
		{:error, reason} -> {:error, reason}
	end
end

@doc """
Verifies authencity of the HMAC (SHA256) signature of `expected`
using the server-side key and `data`.
strings.
"""
@spec hmac_verify(String.t(), String.t()) :: :ok | {:error, term()}
def hmac_verify(data, expected) do
	data = %{"data" => data, "expected" => expected, "key" => salt()}
	case exec("hmac_verify", data) do
		{:ok, %{"output" => ["1"]}} -> :ok
		{:error, reason} -> {:error, reason}
	end
end

# Execute a Zencode specified by `name` with JSON data `data`.
@spec exec(String.t(), map()) :: {:ok, map()} | {:error, term()}
defp exec(name, post_data) do
	request(&Zenflows.HTTPC.request(__MODULE__, &1, &2, &3, &4),
		name, post_data)
@doc """
Generate the HMAC (SHA256) signature of `data` using the server-side key.

The returned value in the ok-tuble, `data`, and `key` are base64-encoded
strings.
"""
@spec hmac_new(String.t()) :: {:ok, String.t()} | {:error, term()}
def hmac_new(data) do
	case exec("hmac_new", %{"data" => data}, %{"key" => salt()}) do
		{:ok, %{"HMAC" => sign}} -> {:ok, sign}
		{:error, reason} -> {:error, reason}
	end
end

@doc """
Given the request function (wrapper of Zenflows.HTTPC.request), the path,
data, and keys to post, it makes the request and parses the result.
"""
@spec request(fun(), String.t(), map()) :: {:ok, map()} | {:error, term()}
def request(request_fn, path, post_data, post_keys \\ %{}) do
	hdrs = [{"content-type", "application/json"}]

	with {:ok, post_body} <- Jason.encode(%{data: Map.merge(post_data, post_keys)}),
			{:ok, %{status: stat, data: body}} when stat == 200 or stat == 500 <-
				request_fn.("POST", "/api/#{path}", hdrs, post_body),
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

# Return the salt from the configs.
@spec salt() :: String.t()
defp salt() do
	Keyword.fetch!(conf(), :room_salt)
end

# Return the scheme of restroom from the configs.
@spec scheme() :: :http | :https
defp scheme() do
	Keyword.fetch!(conf(), :room_uri).scheme
end

# Return the hostname of restroom from the configs.
@spec host() :: String.t()
defp host() do
	Keyword.fetch!(conf(), :room_uri).host
end

# Return the port of restroom from the configs.
@spec port() :: non_neg_integer()
defp port() do
	Keyword.fetch!(conf(), :room_uri).port
end

# Return the application configurations of this module.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, __MODULE__)
end
end
