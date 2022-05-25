defmodule ZenflowsTest.VF.Plan.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Plan, Plan.Domain, Scenario}

setup ctx do
	params = %{
		name: Factory.uniq("name"),
		note: Factory.uniq("note"),
		created: DateTime.utc_now(),
		due: DateTime.utc_now(),
		refinement_of_id: Factory.insert!(:scenario).id,
 	}

	if ctx[:no_insert] do
		%{params: params}
	else
		%{params: params, inserted: Factory.insert!(:plan)}
	end
end

test "by_id/1 returns a Plan", %{inserted: plan} do
	assert %Plan{} = Domain.by_id(plan.id)
end

describe "create/1" do
	@tag :no_insert
	test "creates a Plan with valid params", %{params: params} do
		assert {:ok, %Plan{} = plan} = Domain.create(params)

		assert plan.name == params.name
		assert plan.note == params.note
		assert plan.created == params.created
		assert plan.due == params.due
		assert plan.refinement_of_id == params.refinement_of_id
	end

	test "doesn't create a Plan with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a Plan with valid params", %{params: params, inserted: old} do
		assert {:ok, %Plan{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
		assert new.created == params.created
		assert new.due == params.due
		assert new.refinement_of_id == params.refinement_of_id
	end

	test "doesn't update a Plan", %{inserted: old} do
		assert {:ok, %Plan{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
		assert new.created == old.created
		assert new.due == old.due
		assert new.refinement_of_id == old.refinement_of_id
	end
end

test "delete/1 deletes a Plan", %{inserted: %{id: id}} do
	assert {:ok, %Plan{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end

describe "preload/2" do
	test "preloads `:refinement_of`", %{inserted: plan} do
		plan = Domain.preload(plan, :refinement_of)
		assert refin_of = %Scenario{} = plan.refinement_of
		assert refin_of.id == plan.refinement_of_id
	end
end
end
