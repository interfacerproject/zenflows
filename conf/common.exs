import Config

alias Zenflows.DB.Repo

config :zenflows, ecto_repos: [Repo]

config :zenflows, Repo,
	migration_primary_key: [type: :binary_id],
	migration_foreign_key: [type: :binary_id],
	migration_timestamps:  [type: :timestamptz]

# use `runtime.exs` for :prod
if (env = config_env()) in [:test, :dev] do
	import_config "#{env}.exs"
end
