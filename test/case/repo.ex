defmodule ZenflowsTest.Case.Repo do
@moduledoc "A helper module to ease writing DB tests."
use ExUnit.CaseTemplate

using do
	quote do
		import Ecto
		import Ecto.Query
		import ZenflowsTest.Case.Repo

		alias Zenflows.Ecto.Repo
		alias ZenflowsTest.Util.Factory
	end
end

setup ctx do
	alias Ecto.Adapters.SQL.Sandbox
	alias Zenflows.Ecto.Repo

	:ok = Sandbox.checkout(Repo)

	unless ctx[:async] do
		Sandbox.mode(Repo, {:shared, self()})
	end

	:ok
end
end
