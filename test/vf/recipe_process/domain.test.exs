defmodule ZenflowsTest.VF.RecipeProcess.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Duration,
	ProcessSpecification,
	RecipeProcess,
	RecipeProcess.Domain,
}

setup ctx do
	params = %{
		name: Factory.uniq("name"),
		note: Factory.uniq("note"),
		process_classified_as: Factory.uniq_list("uri"),
		process_conforms_to_id: Factory.insert!(:process_specification).id,
		has_duration: Factory.build(:iduration),
 	}

	if ctx[:no_insert] do
		%{params: params}
	else
		%{params: params, inserted: Factory.insert!(:recipe_process)}
	end
end

test "by_id/1 returns a RecipeProcess", %{inserted: rec_proc} do
	assert %RecipeProcess{} = Domain.by_id(rec_proc.id)
end

describe "create/1" do
	@tag :no_insert
	test "creates a RecipeProcess with valid params without :has_duration", %{params: params} do
		params = Map.delete(params, :has_duration)

		assert {:ok, %RecipeProcess{} = rec_proc} = Domain.create(params)

		assert rec_proc.name == params.name
		assert rec_proc.note == params.note
		assert rec_proc.process_classified_as == params.process_classified_as
		assert rec_proc.process_conforms_to_id == params.process_conforms_to_id
		assert rec_proc.has_duration_unit_type == nil
		assert rec_proc.has_duration_numeric_duration == nil
	end

	@tag :no_insert
	test "creates a RecipeProcess with valid params with :has_duration", %{params: params} do
		assert {:ok, %RecipeProcess{} = rec_proc} = Domain.create(params)

		assert rec_proc.name == params.name
		assert rec_proc.note == params.note
		assert rec_proc.process_classified_as == params.process_classified_as
		assert rec_proc.process_conforms_to_id == params.process_conforms_to_id
		assert rec_proc.has_duration_unit_type == params.has_duration.unit_type
		assert rec_proc.has_duration_numeric_duration == params.has_duration.numeric_duration
	end

	@tag :no_insert
	test "creates a RecipeProcess with valid params with :has_duration set to nil", %{params: params} do
		params = Map.put(params, :has_duration, nil)

		assert {:ok, %RecipeProcess{} = rec_proc} = Domain.create(params)

		assert rec_proc.name == params.name
		assert rec_proc.note == params.note
		assert rec_proc.process_classified_as == params.process_classified_as
		assert rec_proc.process_conforms_to_id == params.process_conforms_to_id
		assert rec_proc.has_duration_unit_type == nil
		assert rec_proc.has_duration_numeric_duration == nil
	end

	@tag :no_insert
	test "doesn't create a RecipeProcess with valid invalid :has_duration fields", %{params: params} do
		params = Map.put(params, :has_duration, %{unit_type: nil, numeric_duration: nil})
		assert {:error, %Changeset{errors: errs}} = Domain.create(params)
		assert length(Keyword.get_values(errs, :has_duration)) == 2

		params = Map.put(params, :has_duration, %{unit_type: nil})
		assert {:error, %Changeset{errors: errs}} = Domain.create(params)
		assert length(Keyword.get_values(errs, :has_duration)) == 2

		params = Map.put(params, :has_duration, %{numeric_duration: nil})
		assert {:error, %Changeset{errors: errs}} = Domain.create(params)
		assert length(Keyword.get_values(errs, :has_duration)) == 2

		params = Map.put(params, :has_duration, %{unit_type: Factory.build(:time_unit)})
		assert {:error, %Changeset{errors: errs}} = Domain.create(params)
		assert Keyword.has_key?(errs, :has_duration)

		params = Map.put(params, :has_duration, %{numeric_duration: Factory.float()})
		assert {:error, %Changeset{errors: errs}} = Domain.create(params)
		assert Keyword.has_key?(errs, :has_duration)
	end

	test "doesn't create a RecipeProcess with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a RecipeProcess with valid params with :has_duration", %{params: params, inserted: old} do
		assert {:ok, %RecipeProcess{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
		assert new.process_classified_as == params.process_classified_as
		assert new.process_conforms_to_id == params.process_conforms_to_id
		assert new.has_duration_unit_type == params.has_duration.unit_type
		assert new.has_duration_numeric_duration == params.has_duration.numeric_duration
	end

	test "updates a RecipeProcess with valid params with :has_duration set to nil", %{params: params, inserted: old} do
		params = Map.put(params, :has_duration, nil)

		assert {:ok, %RecipeProcess{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
		assert new.process_classified_as == params.process_classified_as
		assert new.process_conforms_to_id == params.process_conforms_to_id
		assert new.has_duration_numeric_duration == nil
		assert new.has_duration_unit_type == nil
	end

	test "doesn't update a RecipeProcess with valid params with :has_duration fields set to nil", %{params: params, inserted: old} do
		params = Map.put(params, :has_duration, %{unit_type: nil, numeric_duration: nil})
		assert {:error, %Changeset{errors: errs}} = Domain.update(old.id, params)
		assert length(Keyword.get_values(errs, :has_duration)) == 2
	end

	test "doesn't update a RecipeProcess", %{inserted: old} do
		assert {:ok, %RecipeProcess{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.note == old.note
		assert new.process_classified_as == old.process_classified_as
		assert new.process_conforms_to_id == old.process_conforms_to_id
		assert new.has_duration_unit_type == old.has_duration_unit_type
		assert new.has_duration_numeric_duration == old.has_duration_numeric_duration
	end
end

test "delete/1 deletes a RecipeProcess", %{inserted: %{id: id}} do
	assert {:ok, %RecipeProcess{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end

describe "preload/2" do
	test "preloads :has_duration", %{inserted: rec_proc} do
		rec_proc = Domain.preload(rec_proc, :has_duration)
		assert has_dur = %Duration{} = rec_proc.has_duration
		assert has_dur.unit_type == rec_proc.has_duration_unit_type
		assert has_dur.numeric_duration == rec_proc.has_duration_numeric_duration
	end

	test "preloads :process_conforms_to", %{inserted: rec_proc} do
		rec_proc = Domain.preload(rec_proc, :process_conforms_to)
		assert proc_con_to = %ProcessSpecification{} = rec_proc.process_conforms_to
		assert proc_con_to.id == rec_proc.process_conforms_to_id
	end
end
end
