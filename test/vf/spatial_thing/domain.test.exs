defmodule ZenflowsTest.VF.SpatialThing.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{SpatialThing, SpatialThing.Domain}

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			mappable_address: Factory.uniq("address"),
			lat: Factory.float(),
			long: Factory.float(),
			alt: Factory.float(),
			note: Factory.uniq("note"),
		},
		spatial_thing: Factory.insert!(:spatial_thing),
	}
end

test "by_id/1 returns a SpatialThing", %{spatial_thing: spt_thg} do
	assert %SpatialThing{} = Domain.by_id(spt_thg.id)
end

describe "create/1" do
	test "creates a SpatialThing with valid params", %{params: params} do
		assert {:ok, %SpatialThing{} = spt_thg} = Domain.create(params)

		assert spt_thg.name == params.name
		assert spt_thg.mappable_address == params.mappable_address
		assert spt_thg.lat == params.lat
		assert spt_thg.long == params.long
		assert spt_thg.alt == params.alt
		assert spt_thg.note == params.note
	end

	test "doesn't create a SpatialThing with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a SpatialThing with valid params", %{params: params, spatial_thing: old} do
		assert {:ok, %SpatialThing{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.mappable_address == params.mappable_address
		assert new.lat == params.lat
		assert new.long == params.long
		assert new.alt == params.alt
		assert new.note == params.note
	end

	test "doesn't update a SpatialThing", %{spatial_thing: old} do
		assert {:ok, %SpatialThing{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.mappable_address == old.mappable_address
		assert new.lat == old.lat
		assert new.long == old.long
		assert new.alt == old.alt
		assert new.note == old.note
	end
end

test "delete/1 deletes a SpatialThing", %{spatial_thing: %{id: id}} do
	assert {:ok, %SpatialThing{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
