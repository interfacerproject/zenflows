defmodule ZenflowsTest.Valflow.Commitment do
use ZenflowsTest.Case.Repo, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.Commitment

setup do
	%{params: %{
		action: Factory.build(:action_enum),
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		input_of_id: Factory.insert!(:process).id,
		output_of_id: Factory.insert!(:process).id,
		resource_classified_as: Factory.uniq_list("uri"),
		resource_quantity_id: Factory.insert!(:measure).id,
		effort_quantity_id: Factory.insert!(:measure).id,
		due: DateTime.utc_now(),
		finished: Factory.bool(),
		note: Factory.uniq("note"),
		# in_scope_of_id:
		agreed_in: Factory.uniq("uri"),
		independent_demand_of_id: Factory.insert!(:plan).id,
		at_location_id: Factory.insert!(:spatial_thing).id,
		clause_of_id: Factory.insert!(:agreement).id,
	}}
end

describe "create Commitment" do
	test "with both :has_point_in_time and :has_beginning", %{params: params} do
		params = params
			|> Map.put(:has_point_in_time, DateTime.utc_now())
			|> Map.put(:has_beginning, DateTime.utc_now())

		assert {:error, %Changeset{errors: errs}} =
			params
			|> Commitment.chset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :has_point_in_time)
		assert {:ok, _} = Keyword.fetch(errs, :has_beginning)
	end

	test "with both :has_point_in_time and :has_end", %{params: params} do
		params = params
			|> Map.put(:has_point_in_time, DateTime.utc_now())
			|> Map.put(:has_end, DateTime.utc_now())

		assert {:error, %Changeset{errors: errs}} =
			params
			|> Commitment.chset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :has_point_in_time)
		assert {:ok, _} = Keyword.fetch(errs, :has_end)
	end

	test "with only :has_point_in_time", %{params: params} do
		params = Map.put(params, :has_point_in_time, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chset()
			|> Repo.insert()

		assert comm.action == params.action
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_id == params.resource_quantity_id
		assert comm.effort_quantity_id == params.effort_quantity_id
		assert comm.has_beginning == nil
		assert comm.has_end == nil
		assert comm.has_point_in_time == params.has_point_in_time
		assert comm.due == params.due
		assert DateTime.compare(comm.created, DateTime.utc_now()) != :gt
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with only :has_beginning", %{params: params} do
		params = Map.put(params, :has_beginning, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chset()
			|> Repo.insert()

		assert comm.action == params.action
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_id == params.resource_quantity_id
		assert comm.effort_quantity_id == params.effort_quantity_id
		assert comm.has_beginning == params.has_beginning
		assert comm.has_end == nil
		assert comm.has_point_in_time == nil
		assert comm.due == params.due
		assert DateTime.compare(comm.created, DateTime.utc_now()) != :gt
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with only :has_end", %{params: params} do
		params = Map.put(params, :has_end, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chset()
			|> Repo.insert()

		assert comm.action == params.action
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_id == params.resource_quantity_id
		assert comm.effort_quantity_id == params.effort_quantity_id
		assert comm.has_beginning == nil
		assert comm.has_end == params.has_end
		assert comm.has_point_in_time == nil
		assert comm.due == params.due
		assert DateTime.compare(comm.created, DateTime.utc_now()) != :gt
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with both :has_beginning and :has_end", %{params: params} do
		params = params
			|> Map.put(:has_beginning, DateTime.utc_now())
			|> Map.put(:has_end, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chset()
			|> Repo.insert()

		assert comm.action == params.action
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_id == params.resource_quantity_id
		assert comm.effort_quantity_id == params.effort_quantity_id
		assert comm.has_beginning == params.has_beginning
		assert comm.has_end == params.has_end
		assert comm.has_point_in_time == nil
		assert comm.due == params.due
		assert DateTime.compare(comm.created, DateTime.utc_now()) != :gt
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with both :resource_conforms_to and :resource_inventoried_as", %{params: params} do
		params = params
			|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
			|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:error, %Changeset{errors: errs}} =
			params
			|> Commitment.chset()
			|> Repo.insert()

		assert {:ok, _} = Keyword.fetch(errs, :resource_conforms_to_id)
		assert {:ok, _} = Keyword.fetch(errs, :resource_inventoried_as_id)
	end

	test "with only :resource_conforms_to", %{params: params} do
		params = params
			|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chset()
			|> Repo.insert()

		assert comm.action == params.action
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == params.resource_conforms_to_id
		assert comm.resource_inventoried_as_id == nil
		assert comm.resource_quantity_id == params.resource_quantity_id
		assert comm.effort_quantity_id == params.effort_quantity_id
		assert comm.has_beginning == nil
		assert comm.has_end == nil
		assert comm.has_point_in_time == params.has_point_in_time
		assert comm.due == params.due
		assert DateTime.compare(comm.created, DateTime.utc_now()) != :gt
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end

	test "with only :resource_inventoried_as", %{params: params} do
		params = params
			|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
			|> Map.put(:has_point_in_time, DateTime.utc_now())

		assert {:ok, %Commitment{} = comm} =
			params
			|> Commitment.chset()
			|> Repo.insert()

		assert comm.action == params.action
		assert comm.provider_id == params.provider_id
		assert comm.receiver_id == params.receiver_id
		assert comm.input_of_id == params.input_of_id
		assert comm.output_of_id == params.output_of_id
		assert comm.resource_classified_as == params.resource_classified_as
		assert comm.resource_conforms_to_id == nil
		assert comm.resource_inventoried_as_id == params.resource_inventoried_as_id
		assert comm.resource_quantity_id == params.resource_quantity_id
		assert comm.effort_quantity_id == params.effort_quantity_id
		assert comm.has_beginning == nil
		assert comm.has_end == nil
		assert comm.has_point_in_time == params.has_point_in_time
		assert comm.due == params.due
		assert DateTime.compare(comm.created, DateTime.utc_now()) != :gt
		assert comm.finished == params.finished
		assert comm.note == params.note
		# assert in_scope_of_id
		assert comm.agreed_in == params.agreed_in
		assert comm.independent_demand_of_id == params.independent_demand_of_id
		assert comm.at_location_id == params.at_location_id
		assert comm.clause_of_id == params.clause_of_id
	end
end

test "with present assocs", %{params: params} do
	old = Factory.insert!(:commitment)

	assert {:ok, %Commitment{} = new} =
		old
		|> Commitment.chset(params)
		|> Repo.update()

	assert new.action == params.action
	assert new.provider_id == params.provider_id
	assert new.receiver_id == params.receiver_id
	assert new.input_of_id == params.input_of_id
	assert new.output_of_id == params.output_of_id
	assert new.resource_classified_as == params.resource_classified_as
	assert new.resource_conforms_to_id == old.resource_conforms_to_id
	assert new.resource_inventoried_as_id == old.resource_inventoried_as_id
	assert new.resource_quantity_id == params.resource_quantity_id
	assert new.effort_quantity_id == params.effort_quantity_id
	assert new.has_beginning == old.has_beginning
	assert new.has_end == old.has_end
	assert new.has_point_in_time == old.has_point_in_time
	assert new.due == params.due
	assert DateTime.compare(new.created, DateTime.utc_now()) != :gt
	assert new.finished == params.finished
	assert new.note == params.note
	# assert in_scope_of_id
	assert new.agreed_in == params.agreed_in
	assert new.independent_demand_of_id == params.independent_demand_of_id
	assert new.at_location_id == params.at_location_id
	assert new.clause_of_id == params.clause_of_id
end
end
