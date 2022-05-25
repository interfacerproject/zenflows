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
