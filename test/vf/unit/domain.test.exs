defmodule ZenflowsTest.VF.Unit.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Unit, Unit.Domain}

setup do
	%{
		params: %{
			label: Factory.uniq("label"),
			symbol: Factory.uniq("symbol"),
		},
		unit: Factory.insert!(:unit),
	}
end

test "by_id/1 returns a Unit", %{unit: unit} do
	assert %Unit{} = Domain.by_id(unit.id)
end

describe "create/1" do
	test "creates a Unit with valid params", %{params: params} do
		assert {:ok, %Unit{} = unit} = Domain.create(params)

		assert unit.label == params.label
		assert unit.symbol == params.symbol
	end

	test "doesn't create a Unit with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a Unit with valid params", %{params: params, unit: old} do
		assert {:ok, %Unit{} = new} = Domain.update(old.id, params)

		assert new.label == params.label
		assert new.symbol == params.symbol
	end

	test "doesn't update a Unit", %{unit: old} do
		assert {:ok, %Unit{} = new} = Domain.update(old.id, %{})

		assert new.label == old.label
		assert new.symbol == old.symbol
	end
end

test "delete/1 deletes a Unit", %{unit: %{id: id}} do
	assert {:ok, %Unit{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
