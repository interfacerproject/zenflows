
defmodule ZenflowsTest.VF.Claim do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Claim

setup do
	%{params: %{
		action_id: Factory.build(:action_id),
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		resource_classified_as: Factory.uniq_list("uri"),
		resource_conforms_to_id: Factory.insert!(:resource_specification).id,
		resource_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
		effort_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
		triggered_by_id: Factory.insert!(:economic_event).id,
		due: DateTime.utc_now(),
		created: DateTime.utc_now(),
		finished: Factory.bool(),
		note: Factory.uniq("note"),
		agreed_in: Factory.uniq("uri"),
		# in_scope_of_id:
	}}
end

@tag skip: "TODO: fix events in factory"
test "create Claim", %{params: params} do
	assert {:ok, %Claim{} = claim} =
		params
		|> Claim.chgset()
		|> Repo.insert()

	assert claim.action_id == params.action_id
	assert claim.provider_id == params.provider_id
	assert claim.receiver_id == params.receiver_id
	assert claim.resource_classified_as == params.resource_classified_as
	assert claim.resource_conforms_to_id == params.resource_conforms_to_id
	assert claim.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert claim.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert claim.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert claim.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	assert claim.triggered_by_id == params.triggered_by_id
	assert claim.due == params.due
	assert claim.created == params.created
	assert claim.finished == params.finished
	assert claim.note == params.note
	assert claim.agreed_in == params.agreed_in
	# assert in_scope_of
end

@tag skip: "TODO: fix events in factory"
test "update Appreciation", %{params: params} do
	assert {:ok, %Claim{} = claim} =
		:claim
		|> Factory.insert!()
		|> Claim.chgset(params)
		|> Repo.update()

	assert claim.action_id == params.action_id
	assert claim.provider_id == params.provider_id
	assert claim.receiver_id == params.receiver_id
	assert claim.resource_classified_as == params.resource_classified_as
	assert claim.resource_conforms_to_id == params.resource_conforms_to_id
	assert claim.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert claim.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert claim.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert claim.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	assert claim.triggered_by_id == params.triggered_by_id
	assert claim.due == params.due
	assert claim.created == params.created
	assert claim.finished == params.finished
	assert claim.note == params.note
	assert claim.agreed_in == params.agreed_in
	# assert in_scope_of
end
end
