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
room_salt = fetch_env!("ROOM_SALT")
if Base.decode16!(room_salt, case: :lower) |> byte_size() != 64,
	do: raise "ROOM_SALT must be a 64-octect long, lowercase-base16-encoded string"

config :zenflows, Zenflows.Restroom,
	room_host: fetch_env!("ROOM_HOST"),
	room_port: fetch_env!("ROOM_PORT"),
	room_salt: room_salt

#
# admin
#
admin_key = fetch_env!("ADMIN_KEY") |> Base.decode16!(case: :lower)
if byte_size(admin_key) != 64,
	do: raise "ADMIN_KEY must be a 64-octect long, lowercase-base16-encoded string"
config :zenflows, Zenflows.Admin,
	admin_key: admin_key
