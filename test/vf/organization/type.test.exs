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
			name: Factory.uniq("name"),
			# image
			classified_as: Factory.uniq_list("uri"),
			note: Factory.uniq("note"),
			primary_location_id: Factory.insert!(:spatial_thing).id,
		},
		org: Factory.insert!(:organization),
	}
end

describe "Query" do
	test "organization()", %{org: org} do
		assert %{data: %{"organization" => data}} =
			query!("""
				organization(id: "#{org.id}") {
					id
					name
					note
					primaryLocation { id }
					classifiedAs
				}
			""")

		assert data["id"] == org.id
		assert data["name"] == org.name
		assert data["note"] == org.note
		assert data["primaryLocation"]["id"] == org.primary_location_id
		assert data["classifiedAs"] == org.classified_as
	end
end

describe "Mutation" do
	test "createOrganization", %{params: params} do
		assert %{data: %{"createOrganization" => %{"agent" => data}}} =
			mutation!("""
				createOrganization(organization: {
					name: "#{params.name}"
					note: "#{params.note}"
					primaryLocation: "#{params.primary_location_id}"
					classifiedAs: #{inspect(params.classified_as)}
				}) {
					agent {
						id
						name
						note
						primaryLocation { id }
						classifiedAs
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["primaryLocation"]["id"] == params.primary_location_id
		assert data["classifiedAs"] == params.classified_as
	end

	test "updateOrganization()", %{params: params, org: org} do
		assert %{data: %{"updateOrganization" => %{"agent" => data}}} =
			mutation!("""
				updateOrganization(organization: {
					id: "#{org.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					primaryLocation: "#{params.primary_location_id}"
					classifiedAs: #{inspect(params.classified_as)}
				}) {
					agent {
						id
						name
						note
						primaryLocation { id }
						classifiedAs
					}
				}
			""")

		assert data["id"] == org.id
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["primaryLocation"]["id"] == params.primary_location_id
		assert data["classifiedAs"] == params.classified_as
	end

	test "deleteOrganization", %{org: org} do
		assert %{data: %{"deleteOrganization" => true}} =
			mutation!("""
				deleteOrganization(id: "#{org.id}")
			""")
	end
end
end
