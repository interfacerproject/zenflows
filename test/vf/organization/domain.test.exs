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

setup ctx do
	if ctx[:no_insert] do
		:ok
	else
		params = %{
			name: Factory.uniq("name"),
			image: Factory.uri(),
			classified_as: Factory.uniq_list("uri"),
			note: Factory.uniq("note"),
			primary_location_id: Factory.insert!(:spatial_thing).id,
		}

		%{params: params, org: Factory.insert!(:organization)}
	end
end

describe "by_id/1" do
	test "returns an Organization", %{org: org} do
		assert %Organization{type: :org} = Domain.by_id(org.id)
	end

	test "doesn't return a Person" do
		per = Factory.insert!(:person)

		assert Domain.by_id(per.id) == nil
	end
end

@tag :no_insert
test "all/0 returns all Organizations" do
	want_ids =
		Enum.map(1..10, fn _ -> Factory.insert!(:organization).id end)
		|> Enum.sort()
	have_ids =
		Domain.all()
		|> Enum.map(& &1.id)
		|> Enum.sort()

	assert have_ids == want_ids
end

describe "create/1" do
	test "creates an Organization with valid params", %{params: params} do
		assert {:ok, %Organization{} = org} = Domain.create(params)

		assert org.type == :org
		assert org.name == params.name
		assert org.image == params.image
		assert org.classified_as == params.classified_as
		assert org.note == params.note
		assert org.primary_location_id == params.primary_location_id
	end

	test "doesn't create an Organization with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates an Organization with valid params", %{params: params, org: old} do
		assert {:ok, %Organization{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.classified_as == params.classified_as
		assert new.note == params.note
		assert new.image == params.image
		assert new.primary_location_id == params.primary_location_id
	end

	test "doesn't update an Organization with invalid params", %{org: old} do
		assert {:ok, %Organization{} = new} = Domain.update(old.id, %{})

		assert new.name == old.name
		assert new.classified_as == old.classified_as
		assert new.note == old.note
		assert new.image == nil # old.image
		assert new.primary_location_id == old.primary_location_id
	end
end

test "delete/1 deletes an Organization", %{org: %{id: id}} do
	assert {:ok, %Organization{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
