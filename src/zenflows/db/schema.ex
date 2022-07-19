# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.DB.Schema do
@moduledoc """
Just a wrapper around Ecto.Schema to customize it.
"""

@type params() :: %{required(binary()) => term()} | %{required(atom()) => term()}
@type id() :: Zenflows.DB.ID.t()

defmacro __using__(opts) do
	types? = Keyword.get(opts, :types?, true)

	quote do
		use Ecto.Schema

		alias Ecto.{Changeset, Schema}

		if unquote(types?) do
			@typep params() :: Zenflows.DB.Schema.params()
		end

		@primary_key {:id, Zenflows.DB.ID, autogenerate: true}
		@foreign_key_type Zenflows.DB.ID
		@timestamps_opts type: :utc_datetime_usec
	end
end
end
