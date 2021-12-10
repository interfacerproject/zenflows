defmodule ZenflowsTest.Valflow.Duration do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Duration

setup do
	%{params: %{
		unit_type: Factory.build(:time_unit_enum),
		numeric_duration: Factory.float(),
	}}
end

test "create Duration", %{params: params} do
	assert {:ok, %Duration{} = dur} =
		params
		|> Duration.chset()
		|> Repo.insert()

	assert dur.unit_type == params.unit_type
	assert dur.numeric_duration == params.numeric_duration
end

test "update duration", %{params: params} do
	dur = Factory.insert!(:duration)

	assert {:ok, %Duration{} = dur} =
		dur
		|> Duration.chset(params)
		|> Repo.update()

	assert dur.unit_type == params.unit_type
	assert dur.numeric_duration == params.numeric_duration
end
end
