defmodule ZenflowsTest.Valflow.Intent do
use ZenflowsTest.Case.Repo, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.Intent

setup do
	%{params: %{
		name: Factory.uniq("name"),
		action: Factory.build(:action_enum),
		input_of_id: Factory.insert!(:process).id,
		output_of_id: Factory.insert!(:process).id,
		resource_classified_as: Factory.uniq_list("uri"),
		resource_conforms_to_id: Factory.insert!(:resource_specification).id,
		resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
		resource_quantity_id: Factory.insert!(:measure).id,
		effort_quantity_id: Factory.insert!(:measure).id,
		available_quantity_id: Factory.insert!(:measure).id,
		at_location_id: Factory.insert!(:spatial_thing).id,
		has_beginning: DateTime.utc_now(),
		has_end: DateTime.utc_now(),
		has_point_in_time: DateTime.utc_now(),
		due: DateTime.utc_now(),
		finished: Factory.bool(),
		image: Factory.uri(),
		note: Factory.uniq("note"),
		# in_scope_of_id:
		agreed_in: Factory.uniq("uri"),
	}}
end

describe "create Intent" do
	test "with only :provider", %{params: params} do
		params = Map.put(params, :provider_id, Factory.insert!(:agent).id)

		assert {:ok, %Intent{} = int} =
			params
			|> Intent.chset()
			|> Repo.insert()

		assert int.name == params.name
		assert int.action == params.action
		assert int.provider_id == params.provider_id
		assert int.receiver_id == nil
		assert int.input_of_id == params.input_of_id
		assert int.output_of_id == params.output_of_id
		assert int.resource_classified_as == params.resource_classified_as
		assert int.resource_conforms_to_id == params.resource_conforms_to_id
		assert int.resource_inventoried_as_id == params.resource_inventoried_as_id
		assert int.resource_quantity_id == params.resource_quantity_id
		assert int.effort_quantity_id == params.effort_quantity_id
		assert int.available_quantity_id == params.available_quantity_id
		assert int.at_location_id == params.at_location_id
		assert int.has_beginning == params.has_beginning
		assert int.has_end == params.has_end
		assert int.has_point_in_time == params.has_point_in_time
		assert int.due == params.due
		assert int.finished == params.finished
		assert int.image == params.image
		assert int.note == params.note
		# assert in_scope_of_id
		assert int.agreed_in == params.agreed_in
	end

	test "with only :receiver", %{params: params} do
		params = Map.put(params, :receiver_id, Factory.insert!(:agent).id)

		assert {:ok, %Intent{} = int} =
			params
			|> Intent.chset()
			|> Repo.insert()

		assert int.name == params.name
		assert int.action == params.action
		assert int.provider_id == nil
		assert int.receiver_id == params.receiver_id
		assert int.input_of_id == params.input_of_id
		assert int.output_of_id == params.output_of_id
		assert int.resource_classified_as == params.resource_classified_as
		assert int.resource_conforms_to_id == params.resource_conforms_to_id
		assert int.resource_inventoried_as_id == params.resource_inventoried_as_id
		assert int.resource_quantity_id == params.resource_quantity_id
		assert int.effort_quantity_id == params.effort_quantity_id
		assert int.available_quantity_id == params.available_quantity_id
		assert int.at_location_id == params.at_location_id
		assert int.has_beginning == params.has_beginning
		assert int.has_end == params.has_end
		assert int.has_point_in_time == params.has_point_in_time
		assert int.due == params.due
		assert int.finished == params.finished
		assert int.image == params.image
		assert int.note == params.note
		# assert in_scope_of_id
		assert int.agreed_in == params.agreed_in
	end

	test "with both :provider and :receiver", %{params: params} do
		params =
			params
			|> Map.put(:provider_id, Factory.insert!(:agent).id)
			|> Map.put(:receiver_id, Factory.insert!(:agent).id)

		assert {:error, %Changeset{errors: errs}} =
			params
			|> Intent.chset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :provider_id)
		assert {:ok, _} = Keyword.fetch(errs, :receiver_id)
	end
end

test "update Intent", %{params: params} do
	old = Factory.insert!(:intent)

	assert {:ok, %Intent{} = new} =
		old
		|> Intent.chset(params)
		|> Repo.update()

	assert new.name == params.name
	assert new.action == params.action
	assert new.provider_id == old.provider_id
	assert new.receiver_id == old.receiver_id
	assert new.input_of_id == params.input_of_id
	assert new.output_of_id == params.output_of_id
	assert new.resource_classified_as == params.resource_classified_as
	assert new.resource_conforms_to_id == params.resource_conforms_to_id
	assert new.resource_inventoried_as_id == params.resource_inventoried_as_id
	assert new.resource_quantity_id == params.resource_quantity_id
	assert new.effort_quantity_id == params.effort_quantity_id
	assert new.available_quantity_id == params.available_quantity_id
	assert new.at_location_id == params.at_location_id
	assert new.has_beginning == params.has_beginning
	assert new.has_end == params.has_end
	assert new.has_point_in_time == params.has_point_in_time
	assert new.due == params.due
	assert new.finished == params.finished
	assert new.image == params.image
	assert new.note == params.note
	# assert in_scope_of_id
	assert new.agreed_in == params.agreed_in
end
end
