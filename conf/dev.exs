import Config

config :zenflows, Zenflows.DB.Repo,
	database: "zenflows_dev",
	hostname: "localhost"

config :zenflows, Zenflows.Crypto.Pass,
	iter: 1024,
	klen: 16,
	slen: 16

# local (private) dev confs
for conf <- "dev.local*.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
	import_config conf
end
