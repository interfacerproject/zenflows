# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.DB.Repo do
@moduledoc "The Ecto Repository of Zenflows."

use Ecto.Repo,
	otp_app: :zenflows,
	adapter: Ecto.Adapters.Postgres

@spec multi((-> :ok | :error | {:ok | :error, term()})
		| (Ecto.Repo.t() -> :ok | :error | {:ok | :error, term()}))
	:: :ok | :error | {:ok | :error, term()}
def multi(fun) when is_function(fun, 0) do
	transaction(fn ->
		case fun.() do
			:ok -> :atom
			:error -> rollback(:atom)
			{:ok, v} -> {:tuple, v}
			{:error, v} -> rollback({:tuple, v})
		end
	end)
	|> case do
		{:ok, :atom} -> :ok
		{:error, :atom} -> :error
		{:ok, {:tuple, v}} -> {:ok, v}
		{:error, {:tuple, v}} -> {:error, v}
	end
end
def multi(fun) when is_function(fun, 1) do
	transaction(fn repo ->
		case fun.(repo) do
			:ok -> :atom
			:error -> rollback(:atom)
			{:ok, v} -> {:tuple, v}
			{:error, v} -> rollback({:tuple, v})
		end
	end)
	|> case do
		{:ok, :atom} -> :ok
		{:error, :atom} -> :error
		{:ok, {:tuple, v}} -> {:ok, v}
		{:error, {:tuple, v}} -> {:error, v}
	end
end
end
