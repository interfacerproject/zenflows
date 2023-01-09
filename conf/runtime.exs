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

import Config
import System, only: [fetch_env!: 1, fetch_env: 1, get_env: 2]

# Just like `System.get_env/2`, but converts the variable to integer if it
# exists or fallbacks to `int`.  It is just a shortcut.
get_env_int = fn varname, int ->
	case fetch_env(varname) do
		{:ok, val} -> String.to_integer(val)
		:error -> int
	end
end

get_env_url = fn varname, default ->
	with {:ok, %{scheme: scheme, host: host, port: port}} when not is_nil(host) and scheme in ["http", "https"]
				  <- URI.new(get_env(varname, default)) do
		%{scheme: :"#{scheme}", host: host, port: port}
	else
		err -> raise err
	end
end

#
# database
#
db_conf = case {fetch_env("DB_URI"), fetch_env("DB_SOCK")} do
	{{:ok, db_uri}, _} ->
		[url: db_uri]

	{_, {:ok, db_sock}} ->
		db_name = case config_env() do
			:prod -> get_env("DB_NAME", "zenflows")
			:dev -> get_env("DB_NAME", "zenflows_dev")
			:test -> get_env("DB_NAME", "zenflows_test")
		end

		[databese: db_name, socket: db_sock]

	_ ->
		db_name = case config_env() do
			:prod -> get_env("DB_NAME", "zenflows")
			:dev -> get_env("DB_NAME", "zenflows_dev")
			:test -> get_env("DB_NAME", "zenflows_test")
		end

		db_port = get_env_int.("DB_PORT", 5432)
		if db_port not in 0..65535,
			do: raise "DB_PORT must be between 0 and 65535 inclusive"

		[
			database: db_name,
			username: fetch_env!("DB_USER"),
			password: fetch_env!("DB_PASS"),
			hostname: get_env("DB_HOST", "localhost"),
			port: db_port,
		]
end

config :zenflows, Zenflows.DB.Repo, db_conf

#
# restroom
#
room_uri = get_env_url.("ROOM_URI", "http://localhost")
config :zenflows, Zenflows.Restroom,
	room_uri: room_uri,
	room_salt: fetch_env!("ROOM_SALT")

#
# did
#
did_keyring = Base.decode64!(get_env("DID_KEYRING", ""))
did_uri = get_env_url.("DID_URI", "https://did.dyne.org")
config :zenflows, Zenflows.DID,
	did_uri: did_uri,
	did_keyring: if(did_keyring == "", do: nil, else: Jason.decode!(did_keyring))

#
# admin
#
admin_key = fetch_env!("ADMIN_KEY") |> Base.decode16!(case: :lower)
if byte_size(admin_key) != 64,
	do: raise "ADMIN_KEY must be a 64-octect long, lowercase-base16-encoded string"
config :zenflows, Zenflows.Admin,
	admin_key: admin_key

#
# gql
#
def_page_size = get_env_int.("GQL_DEF_PAGE_SIZE", 50)
if def_page_size < 1,
	do: raise "GQL_DEF_PAGE_SIZE must be greater than 1"
max_page_size = get_env_int.("GQL_MAX_PAGE_SIZE", 100)
if max_page_size < def_page_size,
	do: raise "GQL_MAX_PAGE_SIZE can't be less than GQL_DEF_PAGE_SIZE"
auth? = get_env("GQL_AUTH_CALLS", "true") != "false"
config :zenflows, Zenflows.GQL,
	def_page_size: def_page_size,
	max_page_size: max_page_size,
	authenticate_calls?: auth?
