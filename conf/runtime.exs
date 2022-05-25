import Config

if config_env() == :prod do
import System, only: [fetch_env!: 1, fetch_env: 1, get_env: 2]

# Just like `System.get_env/2`, but converts the variable to integer if it
# exists or fallbacks to `int`.  It is just a shortcut.
get_env_int = fn (varname, int) ->
	case fetch_env(varname) do
		{:ok, val} -> String.to_integer(val)
		:error -> int
	end
end

#
# database
#
db_name = get_env("DB_NAME", "zenflows")
db_conf = case fetch_env("DB_SOCK") do
	{:ok, db_sock} ->
		[database: db_name, socket: db_sock]

	:error ->
		[
			database: db_name,
			username: fetch_env!("DB_USER"),
			password: fetch_env!("DB_PASS"),
			hostname: get_env("DB_HOST", "localhost"),
			port: get_env_int.("DB_PORT", 5432),
		]
end

if db_conf[:port] not in 0..65535,
	do: raise "DB_PORT must be between 0 and 65535"

config :zenflows, Zenflows.DB.Repo, db_conf

#
# passphrase
#
pass_conf = [
	iter: get_env_int.("PASS_ITER", 160000),
	klen: get_env_int.("PASS_KLEN", 64),
	slen: get_env_int.("PASS_SLEN", 64),
]

if pass_conf[:iter] not in 1024..1073741823,
	do: raise "PASS_ITER must be between 1024 and 1073741823 inclusive."
if pass_conf[:klen] not in 16..4294967295,
	do: raise "PASS_KLEN must be between 16 and 4294967295 inclusive."
if pass_conf[:slen] not in 16..255,
	do: raise "PASS_SLEN must be between 16 and 255 inclusive."

config :zenflows, Zenflows.Crypto.Pass, pass_conf
end
