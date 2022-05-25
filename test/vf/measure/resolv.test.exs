defmodule ZenflowsTest.VF.Measure.Type do
use ZenflowsTest.Help.AbsinCase, async: true

alias Zenflows.VF.{
	Measure.Resolv,
	RecipeFlow,
	Unit,
}

setup do
	# TODO: Can this be not depen on another schema?
	%{recipe_flow: Factory.insert!(:recipe_flow)}
end

test "has_unit/3 returns a Unit", %{recipe_flow: rec_flow} do
	%{resource_quantity: meas} = RecipeFlow.Domain.preload(rec_flow, :resource_quantity)
	assert {:ok, %Unit{} = unit} = Resolv.has_unit(meas, %{}, %{})
	assert unit.id == meas.has_unit_id
end
end
