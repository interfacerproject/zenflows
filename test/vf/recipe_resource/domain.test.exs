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

defmodule ZenflowsTest.VF.RecipeResource.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	RecipeResource,
	RecipeResource.Domain,
	Unit,
}

setup do
	%{
		params: %{
			name: Factory.str("name"),
			resource_classified_as: Factory.str_list("uri"),
			unit_of_effort_id: Factory.insert!(:unit).id,
			unit_of_resource_id: Factory.insert!(:unit).id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			substitutable: Factory.bool(),
			note: Factory.str("note"),
		},
		inserted: Factory.insert!(:recipe_resource),
	}
end

describe "one/1" do
	test "with good id: finds the RecipeResource", %{inserted: %{id: id}} do
		assert {:ok, %RecipeResource{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the RecipeResource" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a RecipeResource", %{params: params} do
		assert {:ok, %RecipeResource{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.resource_classified_as == params.resource_classified_as
		assert new.unit_of_resource_id == params.unit_of_resource_id
		assert new.unit_of_effort_id == params.unit_of_effort_id
		assert new.resource_conforms_to_id == params.resource_conforms_to_id
		assert new.substitutable == params.substitutable
		assert new.note == params.note
	end

	test "with bad params: doesn't create a Process" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the RecipeResource", %{params: params, inserted: old} do
		assert {:ok, %RecipeResource{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.resource_classified_as == params.resource_classified_as
		assert new.unit_of_resource_id == params.unit_of_resource_id
		assert new.unit_of_effort_id == params.unit_of_effort_id
		assert new.resource_conforms_to_id == params.resource_conforms_to_id
		assert new.substitutable == params.substitutable
		assert new.note == params.note
	end

	test "with bad params: doesn't update the RecipeResource", %{inserted: old} do
		assert {:ok, %RecipeResource{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.resource_classified_as == old.resource_classified_as
		assert new.unit_of_resource_id == old.unit_of_resource_id
		assert new.unit_of_effort_id == old.unit_of_effort_id
		assert new.resource_conforms_to_id == old.resource_conforms_to_id
		assert new.substitutable == old.substitutable
		assert new.note == old.note
	end
end

describe "delete/1" do
	test "with good id: deletes the RecipeResource", %{inserted: %{id: id}} do
		assert {:ok, %RecipeResource{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the RecipeResource" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end

describe "preload/2" do
	test "preloads :unit_of_resource", %{inserted: rec_res} do
		rec_res = Domain.preload(rec_res, :unit_of_resource)
		assert unit_res = %Unit{} = rec_res.unit_of_resource
		assert unit_res.id == rec_res.unit_of_resource_id
	end

	test "preloads :unit_of_effort", %{inserted: rec_res} do
		rec_res = Domain.preload(rec_res, :unit_of_effort)
		assert unit_eff = %Unit{} = rec_res.unit_of_effort
		assert unit_eff.id == rec_res.unit_of_effort_id
	end
end
end
