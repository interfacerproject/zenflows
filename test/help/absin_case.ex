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

defmodule ZenflowsTest.Help.AbsinCase do
@moduledoc "A helper module to ease writing GraphQL tests."
use ExUnit.CaseTemplate

using do
	quote do
		import ZenflowsTest.Help.AbsinCase

		alias ZenflowsTest.Help.Factory
	end
end

setup ctx do
	alias Ecto.Adapters.SQL.Sandbox
	alias Zenflows.DB.Repo

	:ok = Sandbox.checkout(Repo)

	unless ctx[:async] do
		Sandbox.mode(Repo, {:shared, self()})
	end

	:ok
end

@spec query!(String.t()) :: Absinthe.run_result()
def query!(doc) do
	run!("query { #{doc} }")
end

@spec mutation!(String.t()) :: Absinthe.run_result()
def mutation!(doc) do
	run!("mutation { #{doc} }")
end

@spec run!(String.t()) :: Absinthe.run_result()
def run!(doc) do
	Absinthe.run!(doc, Zenflows.GQL.Schema)
end
end
