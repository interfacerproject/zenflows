
defmodule ZenflowsTest.Valflow.Claim do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.Claim

setup do
	%{params: %{
		action: Factory.build(:action_enum),
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		resource_classified_as: Factory.uniq_list("uri"),
		resource_conforms_to_id: Factory.insert!(:resource_specification).id,
		resource_quantity_id: Factory.insert!(:measure).id,
		effort_quantity_id: Factory.insert!(:measure).id,
		triggered_by_id: Factory.insert!(:economic_event).id,
		due: DateTime.utc_now(),
		created: DateTime.utc_now(),
		finished: Factory.bool(),
		note: Factory.uniq("note"),
		agreed_in: Factory.uniq("uri"),
		# in_scope_of_id:
	}}
end

test "create Claim", %{params: params} do
	assert {:ok, %Claim{} = claim} =
		params
		|> Claim.chset()
		|> Repo.insert()

	assert claim.action == params.action
	assert claim.provider_id == params.provider_id
	assert claim.receiver_id == params.receiver_id
	assert claim.resource_classified_as == params.resource_classified_as
	assert claim.resource_conforms_to_id == params.resource_conforms_to_id
	assert claim.resource_quantity_id == params.resource_quantity_id
	assert claim.effort_quantity_id == params.effort_quantity_id
	assert claim.triggered_by_id == params.triggered_by_id
	assert claim.due == params.due
	assert claim.created == params.created
	assert claim.finished == params.finished
	assert claim.note == params.note
	assert claim.agreed_in == params.agreed_in
	# assert in_scope_of
end

test "update Appreciation", %{params: params} do
	assert {:ok, %Claim{} = claim} =
		:claim
		|> Factory.insert!()
		|> Claim.chset(params)
		|> Repo.update()

	assert claim.action == params.action
	assert claim.provider_id == params.provider_id
	assert claim.receiver_id == params.receiver_id
	assert claim.resource_classified_as == params.resource_classified_as
	assert claim.resource_conforms_to_id == params.resource_conforms_to_id
	assert claim.resource_quantity_id == params.resource_quantity_id
	assert claim.effort_quantity_id == params.effort_quantity_id
	assert claim.triggered_by_id == params.triggered_by_id
	assert claim.due == params.due
	assert claim.created == params.created
	assert claim.finished == params.finished
	assert claim.note == params.note
	assert claim.agreed_in == params.agreed_in
	# assert in_scope_of
end
end
