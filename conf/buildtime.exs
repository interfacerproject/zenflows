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

alias Zenflows.DB.Repo

config :zenflows, ecto_repos: [Repo]

config :zenflows, Repo,
	migration_primary_key: [type: :binary_id],
	migration_foreign_key: [type: :binary_id],
	migration_timestamps:  [type: :timestamptz, inserted_at: false],
	queue_target: 60_000 # 1 min


if config_env() == :test do
	config :zenflows, Repo,
		pool: Ecto.Adapters.SQL.Sandbox,
		log: false
end
