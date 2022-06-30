defmodule Zenflows.Restroom do
@moduledoc """
A module to interact with Restroom instances over (for now) HTTP.
"""

@doc """
Generate a hash out of a passhprase character string using a constant salt.
"""
@spec passgen(String.t()) :: String.t()
def passgen(pass) do
	data = %{salt: salt(), password: pass}
	{:ok, %{"key_derivation" => keyder}} = exec("passgen_pbkdf2", data)
	keyder
end

@doc """
Securely compare a passphrase and a hash, and return `true` if they match,
`false` otherwise.
"""
@spec passverify?(String.t(), String.t()) :: boolean()
def passverify?(pass, hash) do
	data = %{salt: salt(), hash: hash, password: pass}
	case exec("passverify_pbkdf2", data) do
		{:ok, %{"output" => ["1"]}} -> true
		_ -> false
	end
end

# Execute a Zencode specified by `name` with JSON data `data`.
@spec exec(String.t(), map()) :: {:ok, map()} | {:error, any()}
defp exec(name, data) do
	url = to_charlist("http://#{host()}/api/#{name}")
	hdrs = [{'user-agent', useragent()}]
	http_opts = [
		{:timeout, 3000}, # 30 seconds
		{:connect_timeout, 500}, # 5 seconds
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


# Return the salt binary that is for passphrase hashing.
defp salt() do
	conf() |> Keyword.fetch!(:room_salt)
end

# Return the application configurations of this module.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, __MODULE__)
end
end