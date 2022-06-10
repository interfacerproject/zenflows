import Config

alias Zenflows.DB.Repo

config :zenflows, ecto_repos: [Repo]

config :zenflows, Repo,
	migration_primary_key: [type: :binary_id],
	migration_foreign_key: [type: :binary_id],
	migration_timestamps:  [type: :timestamptz]

if config_env() == :test do
	config :zenflows, Repo,
		pool: Ecto.Adapters.SQL.Sandbox,
		log: false
end
