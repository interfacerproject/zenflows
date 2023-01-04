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

defmodule ZenflowsTest.Help.EctoCase do
@moduledoc "A helper module to ease writing DB tests."
use ExUnit.CaseTemplate

using do
	quote do
		import Ecto
		import Ecto.Query
		import ZenflowsTest.Help.EctoCase

		alias Zenflows.DB.Repo
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
end
