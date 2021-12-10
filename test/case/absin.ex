defmodule ZenflowsTest.Case.Absin do
@moduledoc "A helper module to ease writing GraphQL tests."
use ExUnit.CaseTemplate

using do
	quote do
		import ZenflowsTest.Case.Absin

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
	Absinthe.run!(doc, Zenflows.Absin.Schema)
end
end
