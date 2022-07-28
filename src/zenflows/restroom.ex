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

defmodule Zenflows.Restroom do
@moduledoc """
A module to interact with Restroom instances over (for now) HTTP.
"""

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
@spec verify_graphql?(binary(), String.t(), String.t()) :: boolean()
def verify_graphql?(body, signature, pubkey) do
	data = %{
		"gql" => Base.encode64(body),
		"eddsa_signature" => signature,
		"eddsa_public_key" => pubkey,
	}
	case exec("verify_graphql", data) do
		{:ok, %{"output" => ["1"]}} -> true
		_ -> false
	end
end

@doc """
See https://github.com/dyne/keypairoom for details.
"""
@spec keypairoom_server(map()) :: {:ok, String.t()} | {:error, term()}
def keypairoom_server(data) do
	data = %{
		"userData" => data,
		"theBackendPassword" => pass(),
	}
	case exec("keypairoomServer-6-7", data) do
		{:ok, %{"seedServerSideShard.HMAC" => hmac}} -> {:ok, hmac}
		{:error, reason} -> {:error, reason}
	end
end

# Execute a Zencode specified by `name` with JSON data `data`.
@spec exec(String.t(), map()) :: {:ok, map()} | {:error, any()}
defp exec(name, data) do
	url = to_charlist("http://#{host()}/api/#{name}")
	hdrs = [{'user-agent', useragent()}]
	http_opts = [
		{:timeout, 30_000}, # 30 seconds
		{:connect_timeout, 5000}, # 5 seconds
		{:autoredirect, false},
	]
	with {:ok, data} <- Jason.encode(%{data: data}),
			{:ok, {{_, 200, _}, _, body_charlist}} <-
				:httpc.request(:post, {url, hdrs, 'application/json', data}, http_opts, []),
			{:ok, map} <- body_charlist |> to_string() |> Jason.decode() do
		{:ok, map}
	else
		{:ok, {{_, stat, _}, _, body_charlist}} ->
			{:error, "the http call result in non-200 status code #{stat}: #{to_string(body_charlist)}"}

		other -> other
	end
end

# Return the useragent to be used by the HTTP client, this module.
@spec useragent() :: charlist()
defp useragent() do
	'zenflows/' ++ Application.spec(:zenflows, :vsn)
end

# Return the host string (hostname:port) of the Restroom instance.
@spec host() :: String.t()
defp host() do
	conf = conf()
	"#{conf[:room_host]}:#{conf[:room_port]}"
end

# Return the passphrase from the configs.
@spec pass() :: String.t()
defp pass() do
	conf = conf()
	conf[:room_pass]
end

# Return the application configurations of this module.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, __MODULE__)
end
end
