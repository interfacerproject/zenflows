defmodule ZenflowsTest.Valflow.RecipeProcess.Domain do
use ZenflowsTest.Case.Repo, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.{
	Duration,
	ProcessSpecification,
	RecipeProcess,
}
alias RecipeProcess.Domain

setup ctx do
	params = %{
		name: Factory.uniq("name"),
		has_duration: Factory.build_map!(:duration),
		process_classified_as: Factory.uniq_list("uri"),
		process_conforms_to_id: Factory.insert!(:process_specification).id,
		note: Factory.uniq("note"),
 	}

	if ctx[:no_insert] do
		%{params: params}
	else
		%{params: params, recipe_process: Factory.insert!(:recipe_process)}
	end
end

test "by_id/1 returns a RecipeProcess", %{recipe_process: rec_proc} do
	assert %RecipeProcess{} = Domain.by_id(rec_proc.id)
end

describe "create/1" do
	@tag :no_insert
	test "creates a RecipeProcess with valid params without :has_duration", %{params: params} do
		params = Map.delete(params, :has_duration)

		assert {:ok, %RecipeProcess{} = rec_proc} = Domain.create(params)

		assert [] = Repo.all(Duration)

		assert rec_proc.name == params.name
		assert rec_proc.has_duration_id == nil
		assert rec_proc.process_classified_as == params.process_classified_as
		assert rec_proc.process_conforms_to_id == params.process_conforms_to_id
		assert rec_proc.note == params.note
	end

	@tag :no_insert
	test "creates a RecipeProcess with valid params with :has_duration", %{params: params} do
		assert {:ok, %RecipeProcess{} = rec_proc} = Domain.create(params)

		assert [dur] = Repo.all(Duration)

		assert rec_proc.name == params.name
		assert rec_proc.has_duration_id == dur.id
		assert rec_proc.process_classified_as == params.process_classified_as
		assert rec_proc.process_conforms_to_id == params.process_conforms_to_id
		assert rec_proc.note == params.note
	end

	test "doesn't create a RecipeProcess with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a RecipeProcess with valid params with a new :has_duration", %{params: params, recipe_process: old} do
		assert [%Duration{} = old_dur] = Repo.all(Duration)

		assert {:ok, %RecipeProcess{} = new} = Domain.update(old.id, params)

		assert [%Duration{} = new_dur] = Repo.all(Duration)

		assert new_dur.id == old_dur.id
		# the :unit might collide, so don't need to check
		assert new_dur.numeric_duration != old_dur.numeric_duration

		assert new.name == params.name
		assert new.has_duration_id == new_dur.id
		assert new.process_classified_as == params.process_classified_as
		assert new.process_conforms_to_id == params.process_conforms_to_id
		assert new.note == params.note
	end

	test "updates a RecipeProcess with valid params with a new :has_duration set to nil", %{params: params, recipe_process: old} do
		params = Map.put(params, :has_duration, nil)

		assert [%Duration{}] = Repo.all(Duration)

		assert {:ok, %RecipeProcess{} = new} = Domain.update(old.id, params)

		assert [] = Repo.all(Duration)

		assert new.name == params.name
		assert new.has_duration_id == nil
		assert new.process_classified_as == params.process_classified_as
		assert new.process_conforms_to_id == params.process_conforms_to_id
		assert new.note == params.note
	end

	test "doesn't update a RecipeProcess", %{recipe_process: old} do
		assert {:ok, %RecipeProcess{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.has_duration_id == old.has_duration_id
		assert new.process_classified_as == old.process_classified_as
		assert new.process_conforms_to_id == old.process_conforms_to_id
		assert new.note == old.note
	end
end

test "delete/1 deletes a RecipeProcess", %{recipe_process: %{id: id}} do
	assert {:ok, %RecipeProcess{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end

describe "preload/2" do
	test "preloads :has_duration", %{recipe_process: rec_proc} do
		rec_proc = Domain.preload(rec_proc, :has_duration)
		assert has_dur = %Duration{} = rec_proc.has_duration
		assert has_dur.id == rec_proc.has_duration_id
	end

	test "preloads :process_conforms_to", %{recipe_process: rec_proc} do
		rec_proc = Domain.preload(rec_proc, :process_conforms_to)
		assert proc_con_to = %ProcessSpecification{} = rec_proc.process_conforms_to
		assert proc_con_to.id == rec_proc.process_conforms_to_id
	end
end
end
