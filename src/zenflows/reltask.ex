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

defmodule Zenflows.Reltask do
@moduledoc "Relesea task commands, such as migrate, rollback."

@typep repo() :: Ecto.Repo.t()

@doc "Apply migrations."
@spec migrate() :: :ok
def migrate() do
	:ok = mig_run(:up, all: true)
end

@spec migrate(Keyword.t()) :: :ok
def migrate(opts) when is_list(opts) do
	:ok = mig_run(:up, opts)
end

@spec migrate(repo()) :: :ok
def migrate(repo) do
	:ok = mig_run(repo, :up, all: true)
end

@doc "Apply migrations."
@spec migrate(repo(), Keyword.t()) :: :ok
def migrate(repo, opts) do
	:ok = mig_run(repo, :up, opts)
end

@doc "Rollback to migrations."
@spec rollback(Keyword.t()) :: :ok
def rollback(opts) when is_list(opts) do
	:ok = mig_run(:down, opts)
end

@spec rollback(integer()) :: :ok
def rollback(ver) do
	:ok = mig_run(:down, to: ver)
end

@doc "Rollback to migrations."
@spec rollback(repo(), Keyword.t()) :: :ok
def rollback(repo, opts) when is_list(opts) do
	:ok = mig_run(repo, :down, opts)
end

@spec rollback(repo(), integer()) :: :ok
def rollback(repo, ver) do
	:ok = mig_run(repo, :down, to: ver)
end

# Run migrations of all repos.  See `mig_run/3` for more info.
@spec mig_run(:up | :down, Keyword.t()) :: :ok
defp mig_run(dir, opts) do
	for repo <- repos() do
		:ok = mig_run(repo, dir, opts)
	end

	:ok
end

# Run migrations of a given repo.  See `Ecto.Migrator.run/4` for more
# info.
@spec mig_run(repo(), :up | :down, Keyword.t()) :: :ok
defp mig_run(repo, dir, opts) do
	alias Ecto.Migrator, as: M

	{:ok, _, _} = M.with_repo(repo, &M.run(&1, dir, opts))

	:ok
end

@spec repos() :: [repo()]
defp repos() do
	Application.load(:zenflows)
	Application.fetch_env!(:zenflows, :ecto_repos)
end
end
