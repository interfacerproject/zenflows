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

defmodule ZenflowsTest.VF.Organization.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"image" => Factory.img(),
			"classifiedAs" => Factory.str_list("uri"),
			"note" => Factory.str("note"),
			"primaryLocation" => Factory.insert!(:spatial_thing).id,
		},
		inserted: Factory.insert!(:organization),
	}
end

@frag """
fragment organization on Organization {
	id
	name
	note
	image
	primaryLocation { id }
	classifiedAs
}
"""

describe "Query" do
	test "organization()", %{inserted: new} do
		assert %{data: %{"organization" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					organization(id: $id) {...organization}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
		assert data["image"] == new.image
		assert data["primaryLocation"]["id"] == new.primary_location_id
		assert data["classifiedAs"] == new.classified_as
	end
end

describe "Mutation" do
	test "createOrganization", %{params: params} do
		assert %{data: %{"createOrganization" => %{"agent" => data}}} =
			run!("""
				#{@frag}
				mutation ($organization: OrganizationCreateParams!) {
					createOrganization(organization: $organization) {
						agent {...organization}
					}
				}
			""", vars: %{"organization" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		data = Map.delete(data, "id")

		assert data["primaryLocation"]["id"] == params["primaryLocation"]
		data = Map.delete(data, "primaryLocation")
		params = Map.delete(params, "primaryLocation")

		assert data == params
	end

	test "updateOrganization()", %{params: params, inserted: old} do
		assert %{data: %{"updateOrganization" => %{"agent" => data}}} =
			run!("""
				#{@frag}
				mutation ($organization: OrganizationUpdateParams!) {
					updateOrganization(organization: $organization) {
						agent {...organization}
					}
				}
			""", vars: %{"organization" =>
				params
				|> Map.take(~w[name note image primaryLocation classifiedAs])
				|> Map.put("id", old.id)
			})

		assert data["id"] == old.id
		keys = ~w[name image note classifiedAs]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["primaryLocation"]["id"] == params["primaryLocation"]
	end

	test "deleteOrganization", %{inserted: %{id: id}} do
		assert %{data: %{"deleteOrganization" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteOrganization(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
