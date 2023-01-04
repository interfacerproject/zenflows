# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule ZenflowsTest.VF.RecipeProcess.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Duration,
	ProcessSpecification,
	RecipeProcess,
	RecipeProcess.Domain,
}

setup do
	%{
		params: %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			process_classified_as: Factory.str_list("uri"),
			process_conforms_to_id: Factory.insert!(:process_specification).id,
			has_duration: Factory.build(:iduration),
		},
		inserted: Factory.insert!(:recipe_process),
	}
end

describe "one/1" do
	test "with good id: finds the RecipeProcess", %{inserted: %{id: id}} do
		assert {:ok, %RecipeProcess{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the RecipeProcess" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params (with :has_duration): creates a RecipeProcess", %{params: params} do
		assert {:ok, %RecipeProcess{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.process_classified_as == params.process_classified_as
		assert new.process_conforms_to_id == params.process_conforms_to_id
		assert new.has_duration_unit_type == params.has_duration.unit_type
		assert new.has_duration_numeric_duration == params.has_duration.numeric_duration
	end

	test "with good params (without :has_duration): creates a RecipeProcess", %{params: params} do
		params = Map.delete(params, :has_duration)
		assert {:ok, %RecipeProcess{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.process_classified_as == params.process_classified_as
		assert new.process_conforms_to_id == params.process_conforms_to_id
		assert new.has_duration_unit_type == nil
		assert new.has_duration_numeric_duration == nil
	end

	test "with good params (with :has_duration set to nil): creates a RecipeProcess", %{params: params} do
		params = Map.put(params, :has_duration, nil)
		assert {:ok, %RecipeProcess{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.process_classified_as == params.process_classified_as
		assert new.process_conforms_to_id == params.process_conforms_to_id
		assert new.has_duration_unit_type == nil
		assert new.has_duration_numeric_duration == nil
	end

	test "with bad params (with bad :has_duration): doesn't create a RecipeProcess", %{params: params} do
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

		params = Map.put(params, :has_duration, %{numeric_duration: Factory.decimal()})
		assert {:error, %Changeset{errors: errs}} = Domain.create(params)
		assert Keyword.has_key?(errs, :has_duration)
	end

	test "with bad params: doesn't create a RecipeProcess" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params (with :has_duration): updates the RecipeProcess", %{params: params, inserted: old} do
		assert {:ok, %RecipeProcess{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.process_classified_as == params.process_classified_as
		assert new.process_conforms_to_id == params.process_conforms_to_id
		assert new.has_duration_unit_type == params.has_duration.unit_type
		assert new.has_duration_numeric_duration == params.has_duration.numeric_duration
	end

	test "with good params (with :has_duration set to nil): updates the RecipeProcess", %{params: params, inserted: old} do
		params = Map.put(params, :has_duration, nil)
		assert {:ok, %RecipeProcess{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.process_classified_as == params.process_classified_as
		assert new.process_conforms_to_id == params.process_conforms_to_id
		assert new.has_duration_numeric_duration == nil
		assert new.has_duration_unit_type == nil
	end

	test "with bad params (with :has_duration fields set to nil): doesn't update the RecipeProcess", %{params: params, inserted: old} do
		params = Map.put(params, :has_duration, %{unit_type: nil, numeric_duration: nil})
		assert {:error, %Changeset{errors: errs}} = Domain.update(old.id, params)
		assert length(Keyword.get_values(errs, :has_duration)) == 2
	end

	test "with bad params: doesn't update the RecipeProcess", %{inserted: old} do
		assert {:ok, %RecipeProcess{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.note == old.note
		assert new.process_classified_as == old.process_classified_as
		assert new.process_conforms_to_id == old.process_conforms_to_id
		assert new.has_duration_unit_type == old.has_duration_unit_type
		assert new.has_duration_numeric_duration == old.has_duration_numeric_duration
	end
end

describe "delete/1" do
	test "with good id: deletes the RecipeProcess", %{inserted: %{id: id}} do
		assert {:ok, %RecipeProcess{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the RecipeProcess" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
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
