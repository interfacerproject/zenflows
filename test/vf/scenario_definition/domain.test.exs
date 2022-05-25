defmodule ZenflowsTest.VF.ScenarioDefinition.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Duration,
	ScenarioDefinition,
	ScenarioDefinition.Domain,
}

setup ctx do
	params = %{
		name: Factory.uniq("name"),
		note: Factory.uniq("note"),
		has_duration: Factory.build(:iduration),
 	}

	if ctx[:no_insert] do
		%{params: params}
	else
		%{params: params, inserted: Factory.insert!(:scenario_definition)}
	end
end

test "by_id/1 returns a ScenarioDefinition", %{inserted: scen_def} do
	assert %ScenarioDefinition{} = Domain.by_id(scen_def.id)
end

describe "create/1" do
	@tag :no_insert
	test "creates a ScenarioDefinition with valid params", %{params: params} do
		assert {:ok, %ScenarioDefinition{} = scen_def} = Domain.create(params)

		assert scen_def.name == params.name
		assert scen_def.note == params.note
		assert scen_def.has_duration_unit_type == params.has_duration.unit_type
		assert scen_def.has_duration_numeric_duration == params.has_duration.numeric_duration
	end

	test "doesn't create a ScenarioDefinition with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a ScenarioDefinition with valid params", %{params: params, inserted: old} do
		assert {:ok, %ScenarioDefinition{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
		assert new.has_duration_unit_type == params.has_duration.unit_type
		assert new.has_duration_numeric_duration == params.has_duration.numeric_duration
	end

	test "doesn't update a ScenarioDefinition", %{inserted: old} do
		assert {:ok, %ScenarioDefinition{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
		assert new.has_duration_unit_type == old.has_duration_unit_type
		assert new.has_duration_numeric_duration == old.has_duration_numeric_duration
	end
end

test "delete/1 deletes a ScenarioDefinition", %{inserted: %{id: id}} do
	assert {:ok, %ScenarioDefinition{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end

describe "preload/2" do
	test "preloads :has_duration", %{inserted: scen_def} do
		scen_def = Domain.preload(scen_def, :has_duration)
		assert has_dur = %Duration{} = scen_def.has_duration
		assert has_dur.unit_type == scen_def.has_duration_unit_type
		assert has_dur.numeric_duration == scen_def.has_duration_numeric_duration
	end
end
end
