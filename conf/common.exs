import Config

alias Zenflows.Ecto.Repo

config :zenflows, ecto_repos: [Repo]

config :zenflows, Repo,
	migration_primary_key: [type: :binary_id],
	migration_foreign_key: [type: :binary_id],
	migration_timestamps:  [type: :utc_datetime_usec]

import_config "#{config_env()}.exs"
