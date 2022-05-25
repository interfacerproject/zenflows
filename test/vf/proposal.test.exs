defmodule ZenflowsTest.VF.Proposal do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Proposal

setup do
	%{params: %{
		name: Factory.uniq("name"),
		has_beginning: DateTime.utc_now(),
		has_end: DateTime.utc_now(),
		unit_based: Factory.bool(),
		note: Factory.uniq("note"),
		eligible_location_id: Factory.build(:spatial_thing).id,
	}}
end

test "create Proposal", %{params: params} do
	assert {:ok, %Proposal{} = prop} =
		params
		|> Proposal.chgset()
		|> Repo.insert()

	assert prop.name == params.name
	assert prop.has_beginning == params.has_beginning
	assert prop.has_end == params.has_end
	assert prop.unit_based == params.unit_based
	assert prop.note == params.note
	assert prop.eligible_location_id == params.eligible_location_id
end

test "update Proposal", %{params: params} do
	assert {:ok, %Proposal{} = prop} =
		:proposal
		|> Factory.insert!()
		|> Proposal.chgset(params)
		|> Repo.update()

	assert prop.name == params.name
	assert prop.has_beginning == params.has_beginning
	assert prop.has_end == params.has_end
	assert prop.unit_based == params.unit_based
	assert prop.note == params.note
	assert prop.eligible_location_id == params.eligible_location_id
end
end
