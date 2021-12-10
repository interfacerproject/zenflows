defmodule ZenflowsTest.Valflow.Measure do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Measure

setup do
	%{params: %{
		has_unit_id: Factory.insert!(:unit).id,
		has_numerical_value: Factory.float(),
	}}
end

test "create Measure", %{params: params} do
	assert {:ok, %Measure{} = meas} =
		params
		|> Measure.chset()
		|> Repo.insert()

	assert meas.has_unit_id == params.has_unit_id
	assert meas.has_numerical_value == params.has_numerical_value
end

test "update Measure", %{params: params} do
	meas = Factory.insert!(:measure)

	assert {:ok, %Measure{} = meas} =
		meas
		|> Measure.chset(params)
		|> Repo.update()

	assert meas.has_unit_id == params.has_unit_id
	assert meas.has_numerical_value == params.has_numerical_value
end
end
