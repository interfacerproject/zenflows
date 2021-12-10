import Config

config :zenflows, Zenflows.Ecto.Repo,
	database: "zenflows_test",
	username: "username",
	password: "password",
	hostname: "localhost",
	pool: Ecto.Adapters.SQL.Sandbox

config :zenflows, Zenflows.Crypto,
	hash: [salt: "salt", iterations: 1, length: 1]
