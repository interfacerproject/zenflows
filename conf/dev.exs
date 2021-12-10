import Config

config :zenflows, Zenflows.Ecto.Repo,
	database: "zenflows_dev",
	username: "username",
	password: "password",
	hostname: "localhost"

config :zenflows, Zenflows.Crypto,
	hash: [salt: "not so secret"]
