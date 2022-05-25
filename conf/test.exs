import Config

config :zenflows, Zenflows.DB.Repo,
	database: "zenflows_test",
	hostname: "localhost",
	pool: Ecto.Adapters.SQL.Sandbox,
	log: false

config :zenflows, Zenflows.Crypto.Pass,
	iter: 1,
	klen: 1,
	slen: 0

# local (private) test confs
for conf <- "test.local*.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
	import_config conf
end
