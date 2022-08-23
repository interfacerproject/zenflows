# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
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

defmodule ZenflowsTest.VF.Organization.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Organization, Organization.Domain}

setup do
	%{
		params: %{
			name: Factory.str("name"),
			image: Factory.img(),
			classified_as: Factory.str_list("uri"),
			note: Factory.str("note"),
			primary_location_id: Factory.insert!(:spatial_thing).id,
		},
		inserted: Factory.insert!(:organization),
	}
end

describe "one/1" do
	test "with good id: finds the Organization", %{inserted: %{id: id}} do
		assert {:ok, %Organization{}} = Domain.one(id)
	end

	test "with per's id: doesn't return a Person" do
		per = Factory.insert!(:person)
		assert {:error, "not found"} = Domain.one(per.id)
	end

	test "with bad id: doesn't find the Organization" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates an Organization", %{params: params} do
		assert {:ok, %Organization{} = new} = Domain.create(params)
		assert new.type == :org
		assert new.name == params.name
		assert new.image == params.image
		assert new.classified_as == params.classified_as
		assert new.note == params.note
		assert new.primary_location_id == params.primary_location_id	end

	test "with bad params: doesn't create an Organization" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the Organization", %{params: params, inserted: old} do
		assert {:ok, %Organization{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.classified_as == params.classified_as
		assert new.note == params.note
		assert new.image == params.image
		assert new.primary_location_id == params.primary_location_id
	end

	test "with bad params: doesn't update the Organization", %{inserted: old} do
		assert {:ok, %Organization{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.classified_as == old.classified_as
		assert new.note == old.note
		assert new.image == old.image
		assert new.primary_location_id == old.primary_location_id
	end
end

describe "delete/1" do
	test "with good id: deletes the Organization", %{inserted: %{id: id}} do
		assert {:ok, %Organization{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the Organization" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end
end
