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

defmodule ZenflowsTest.VF.ResourceSpecification.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	ResourceSpecification,
	ResourceSpecification.Domain,
	Unit,
}

setup do
	%{
		params: %{
			name: Factory.str("name"),
			resource_classified_as: Factory.str_list("uri"),
			note: Factory.str("note"),
			default_unit_of_effort_id: Factory.insert!(:unit).id,
			default_unit_of_resource_id: Factory.insert!(:unit).id,
		},
		inserted: Factory.insert!(:resource_specification),
	}
end

describe "one/1" do
	test "with good id: finds the ResourceSpecification", %{inserted: %{id: id}} do
		assert {:ok, %ResourceSpecification{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the ResourceSpecification" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a ResourceSpecification", %{params: params} do
		assert {:ok, %ResourceSpecification{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.resource_classified_as == params.resource_classified_as
		assert new.note == params.note
		assert new.default_unit_of_resource_id == params.default_unit_of_resource_id
		assert new.default_unit_of_effort_id == params.default_unit_of_effort_id
	end

	test "with bad params: doesn't create a ResourceSpecification" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the ResourceSpecification", %{params: params, inserted: old} do
		assert {:ok, %ResourceSpecification{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.resource_classified_as == params.resource_classified_as
		assert new.note == params.note
		assert new.default_unit_of_resource_id == params.default_unit_of_resource_id
		assert new.default_unit_of_effort_id == params.default_unit_of_effort_id
	end

	test "with bad params: doesn't update the ResourceSpecification", %{inserted: old} do
		assert {:ok, %ResourceSpecification{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.resource_classified_as == old.resource_classified_as
		assert new.note == old.note
		assert new.default_unit_of_resource_id == old.default_unit_of_resource_id
		assert new.default_unit_of_effort_id == old.default_unit_of_effort_id
	end
end

describe "delete/1" do
	test "with good id: deletes the ResourceSpecification", %{inserted: %{id: id}} do
		assert {:ok, %ResourceSpecification{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the ResourceSpecification" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end

describe "preload/2" do
	test "preloads `:default_unit_of_resource`", %{inserted: %{id: id}} do
		assert {:ok, res_spec} =  Domain.one(id)
		res_spec = Domain.preload(res_spec, :default_unit_of_resource)
		assert %Unit{} = res_spec.default_unit_of_resource
 	end

	test "preloads `:default_unit_of_effort`", %{inserted: %{id: id}} do
		assert {:ok, res_spec} =  Domain.one(id)
		res_spec = Domain.preload(res_spec, :default_unit_of_effort)
		assert %Unit{} = res_spec.default_unit_of_effort
 	end
end
end
