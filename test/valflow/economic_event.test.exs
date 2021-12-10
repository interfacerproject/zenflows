defmodule ZenflowsTest.Valflow.EconomicEvent do
use ZenflowsTest.Case.Repo, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.EconomicEvent

setup do
	%{params: %{
		action: Factory.build(:action_enum),
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		input_of_id: Factory.insert!(:process).id,
		output_of_id: Factory.insert!(:process).id,
		resource_classified_as: Factory.uniq_list("uri"),
		#resource_conforms_to_id: Factory.insert!(:resource_specification).id,
		resource_quantity_id: Factory.insert!(:measure).id,
		effort_quantity_id: Factory.insert!(:measure).id,
		realization_of_id: Factory.insert!(:agreement).id,
		at_location_id: Factory.insert!(:spatial_thing).id,
		note: Factory.uniq("note"),
		# in_scope_of_id:
		agreed_in: Factory.uniq("uri"),
		triggered_by_id: Factory.insert!(:economic_event).id,
	}}
end

describe "create EconomicEvent" do
	test "with both :resource_conforms_to and :resource_inventoried_as", %{params: params} do
		params = params
			|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
			|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:error, %Changeset{errors: errs}} =
			params
			|> EconomicEvent.chset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :resource_conforms_to_id)
		assert {:ok, _} = Keyword.fetch(errs, :resource_inventoried_as_id)
	end

	test "with both :resource_conforms_to and :to_resource_inventoried_as", %{params: params} do
		params = params
			|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
			|> Map.put(:to_resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:error, %Changeset{errors: errs}} =
			params
			|> EconomicEvent.chset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :resource_conforms_to_id)
		assert {:ok, _} = Keyword.fetch(errs, :to_resource_inventoried_as_id)
	end

	test "with only :resource_inventoried_as", %{params: params} do
		params = params
			|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:ok, %EconomicEvent{} = eco_evt} =
			params
			|> EconomicEvent.chset()
			|> Repo.insert()

		assert eco_evt.action == params.action
		assert eco_evt.provider_id == params.provider_id
		assert eco_evt.receiver_id == params.receiver_id
		assert eco_evt.input_of_id == params.input_of_id
		assert eco_evt.output_of_id == params.output_of_id
		assert eco_evt.resource_inventoried_as_id == params.resource_inventoried_as_id
		assert eco_evt.to_resource_inventoried_as_id == nil
		assert eco_evt.resource_classified_as == params.resource_classified_as
		assert eco_evt.resource_conforms_to_id == nil
		assert eco_evt.resource_quantity_id == params.resource_quantity_id
		assert eco_evt.effort_quantity_id == params.effort_quantity_id
		assert eco_evt.realization_of_id == params.realization_of_id
		assert eco_evt.at_location_id == params.at_location_id
		assert eco_evt.has_beginning == nil
		assert eco_evt.has_end == nil
		assert eco_evt.has_point_in_time == params.has_point_in_time
		assert eco_evt.note == params.note
		# assert in_scope_of
		assert eco_evt.agreed_in == params.agreed_in
		assert eco_evt.triggered_by_id == params.triggered_by_id
	end

	test "with only :to_resource_inventoried_as", %{params: params} do
		params = params
			|> Map.put(:to_resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:ok, %EconomicEvent{} = eco_evt} =
			params
			|> EconomicEvent.chset()
			|> Repo.insert()

		assert eco_evt.action == params.action
		assert eco_evt.provider_id == params.provider_id
		assert eco_evt.receiver_id == params.receiver_id
		assert eco_evt.input_of_id == params.input_of_id
		assert eco_evt.output_of_id == params.output_of_id
		assert eco_evt.resource_inventoried_as_id == nil
		assert eco_evt.to_resource_inventoried_as_id == params.to_resource_inventoried_as_id
		assert eco_evt.resource_classified_as == params.resource_classified_as
		assert eco_evt.resource_conforms_to_id == nil
		assert eco_evt.resource_quantity_id == params.resource_quantity_id
		assert eco_evt.effort_quantity_id == params.effort_quantity_id
		assert eco_evt.realization_of_id == params.realization_of_id
		assert eco_evt.at_location_id == params.at_location_id
		assert eco_evt.has_beginning == nil
		assert eco_evt.has_end == nil
		assert eco_evt.has_point_in_time == params.has_point_in_time
		assert eco_evt.note == params.note
		# assert in_scope_of
		assert eco_evt.agreed_in == params.agreed_in
		assert eco_evt.triggered_by_id == params.triggered_by_id
	end

	test "with both :resource_inventoried_as and :to_resource_inventoried_as", %{params: params} do
		params = params
			|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:to_resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:ok, %EconomicEvent{} = eco_evt} =
			params
			|> EconomicEvent.chset()
			|> Repo.insert()

		assert eco_evt.action == params.action
		assert eco_evt.provider_id == params.provider_id
		assert eco_evt.receiver_id == params.receiver_id
		assert eco_evt.input_of_id == params.input_of_id
		assert eco_evt.output_of_id == params.output_of_id
		assert eco_evt.resource_inventoried_as_id == params.resource_inventoried_as_id
		assert eco_evt.to_resource_inventoried_as_id == params.to_resource_inventoried_as_id
		assert eco_evt.resource_classified_as == params.resource_classified_as
		assert eco_evt.resource_conforms_to_id == nil
		assert eco_evt.resource_quantity_id == params.resource_quantity_id
		assert eco_evt.effort_quantity_id == params.effort_quantity_id
		assert eco_evt.realization_of_id == params.realization_of_id
		assert eco_evt.at_location_id == params.at_location_id
		assert eco_evt.has_beginning == nil
		assert eco_evt.has_end == nil
		assert eco_evt.has_point_in_time == params.has_point_in_time
		assert eco_evt.note == params.note
		# assert in_scope_of
		assert eco_evt.agreed_in == params.agreed_in
		assert eco_evt.triggered_by_id == params.triggered_by_id
	end

	test "with only :resource_conforms_to", %{params: params} do
		params = params
			|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:ok, %EconomicEvent{} = eco_evt} =
			params
			|> EconomicEvent.chset()
			|> Repo.insert()

		assert eco_evt.action == params.action
		assert eco_evt.provider_id == params.provider_id
		assert eco_evt.receiver_id == params.receiver_id
		assert eco_evt.input_of_id == params.input_of_id
		assert eco_evt.output_of_id == params.output_of_id
		assert eco_evt.resource_inventoried_as_id == nil
		assert eco_evt.to_resource_inventoried_as_id == nil
		assert eco_evt.resource_classified_as == params.resource_classified_as
		assert eco_evt.resource_conforms_to_id == params.resource_conforms_to_id
		assert eco_evt.resource_quantity_id == params.resource_quantity_id
		assert eco_evt.effort_quantity_id == params.effort_quantity_id
		assert eco_evt.realization_of_id == params.realization_of_id
		assert eco_evt.at_location_id == params.at_location_id
		assert eco_evt.has_beginning == nil
		assert eco_evt.has_end == nil
		assert eco_evt.has_point_in_time == params.has_point_in_time
		assert eco_evt.note == params.note
		# assert in_scope_of
		assert eco_evt.agreed_in == params.agreed_in
		assert eco_evt.triggered_by_id == params.triggered_by_id
	end
end

test "update EconomicEvent", %{params: params} do
	old = Factory.insert!(:economic_event)

	assert {:ok, %EconomicEvent{} = new} =
		old
		|> EconomicEvent.chset(params)
		|> Repo.update()

	assert new.action == old.action
	assert new.provider_id == old.provider_id
	assert new.receiver_id == old.receiver_id
	assert new.input_of_id == old.input_of_id
	assert new.output_of_id == old.output_of_id
	assert new.resource_inventoried_as_id == old.resource_inventoried_as_id
	assert new.to_resource_inventoried_as_id == old.to_resource_inventoried_as_id
	assert new.resource_classified_as == old.resource_classified_as
	assert new.resource_conforms_to_id == old.resource_conforms_to_id
	assert new.resource_quantity_id == old.resource_quantity_id
	assert new.effort_quantity_id == old.effort_quantity_id
	assert new.realization_of_id == params.realization_of_id
	assert new.at_location_id == old.at_location_id
	assert new.has_beginning == old.has_beginning
	assert new.has_end == old.has_end
	assert new.has_point_in_time == old.has_point_in_time
	assert new.note == params.note
	# assert in_scope_of
	assert new.agreed_in == params.agreed_in
	assert new.triggered_by_id == old.triggered_by_id
end
end
