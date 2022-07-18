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
Given the GraphQL `body`, its `signature`, and the `pubkeys`
of the user who executes the query, verify that everything matches.
"""
@spec verify_graphql?(binary(), String.t(), binary()) :: boolean()
def verify_graphql?(body, signature, pubkeys) do
	data = %{
		"graphql" => Base.encode64(body),
		"eddsa signature" => signature,
		"pubkeys" => Base.encode64(pubkeys),
	}
	case exec("verify_graphql", data) do
		{:ok, %{"output" => ["VALID SIGNATURE"]}} -> true
		_ -> false
	end
end

# Execute a Zencode specified by `name` with JSON data `data`.
@spec exec(String.t(), map()) :: {:ok, map()} | {:error, any()}
defp exec(name, data) do
	url = to_charlist("http://#{host()}/api/#{name}")
	hdrs = [{'user-agent', useragent()}]
	http_opts = [
		{:timeout, 30000}, # 30 seconds
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

# Return the application configurations of this module.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, __MODULE__)
end
end
