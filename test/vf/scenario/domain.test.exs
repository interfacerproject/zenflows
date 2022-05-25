defmodule ZenflowsTest.VF.Scenario.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Scenario,
	Scenario.Domain,
	ScenarioDefinition,
}

setup ctx do
	params = %{
		name: Factory.uniq("name"),
		note: Factory.uniq("note"),
		has_beginning: DateTime.utc_now(),
		has_end: DateTime.utc_now(),
		defined_as_id: Factory.insert!(:scenario_definition).id,
		refinement_of_id: Factory.insert!(:scenario).id,
 	}

	if ctx[:no_insert] do
		%{params: params}
	else
		%{params: params, inserted: Factory.insert!(:scenario)}
	end
end

test "by_id/1 returns a Scenario", %{inserted: scen} do
	assert %Scenario{} = Domain.by_id(scen.id)
end

describe "create/1" do
	@tag :no_insert
	test "creates a Scenario with valid params", %{params: params} do
		assert {:ok, %Scenario{} = scen} = Domain.create(params)

		assert scen.name == params.name
		assert scen.note == params.note
		assert scen.has_beginning == params.has_beginning
		assert scen.has_end == params.has_end
		assert scen.defined_as_id == params.defined_as_id
		assert scen.refinement_of_id == params.refinement_of_id
	end

	test "doesn't create a Scenario with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a Scenario with valid params", %{params: params, inserted: old} do
		assert {:ok, %Scenario{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
		assert new.has_beginning == params.has_beginning
		assert new.has_end == params.has_end
		assert new.defined_as_id == params.defined_as_id
		assert new.refinement_of_id == params.refinement_of_id
	end

	test "doesn't update a Scenario", %{inserted: old} do
		assert {:ok, %Scenario{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
		assert new.has_beginning == old.has_beginning
		assert new.has_end == old.has_end
		assert new.defined_as_id == old.defined_as_id
		assert new.refinement_of_id == old.refinement_of_id
	end
end

test "delete/1 deletes a Scenario", %{inserted: %{id: id}} do
	assert {:ok, %Scenario{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end

describe "preload/2" do
	test "preloads `:defined_as`", %{inserted: scen} do
		scen = Domain.preload(scen, :defined_as)
		assert scen_def = %ScenarioDefinition{} = scen.defined_as
		assert scen_def.id == scen.defined_as_id
	end

	test "preloads `:refinement_of`", %{inserted: scen} do
		scen = Domain.preload(scen, :refinement_of)
		# since it has 50% chance
		if scen.refinement_of != nil do
			assert refin_of = %Scenario{} = scen.refinement_of
			assert refin_of.id == scen.refinement_of_id
		end
	end
end
end
