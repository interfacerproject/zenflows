defmodule ZenflowsTest.Valflow.Measure.Type do
use ZenflowsTest.Case.Absin, async: true

alias Zenflows.Valflow.Measure.Resolv
alias Zenflows.Valflow.Unit

setup do
	%{measure: Factory.insert!(:measure)}
end

test "has_unit/3 returns a Unit", %{measure: meas} do
	assert {:ok, %Unit{} = unit} = Resolv.has_unit(meas, %{}, %{})
	assert unit.id == meas.has_unit_id
end
end
