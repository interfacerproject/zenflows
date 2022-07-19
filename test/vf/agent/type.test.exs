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

defmodule ZenflowsTest.VF.Agent.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		per: Factory.insert!(:person),
		org: Factory.insert!(:organization),
	}
end

test "Query myAgent" do
	assert %{data: %{"myAgent" => data}} =
		query!("""
			myAgent {
				id
				name
				image
				note
			}
		""")

	assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
	assert data["name"] == "hello"
	assert data["image"] == "https://example.test/img.jpg"
	assert data["note"] == "world"
end

describe "Query agent()" do
	test "as Agent with Person concrete type", %{per: per} do
		assert %{data: %{"agent" => data}} =
			query!("""
				agent(id: "#{per.id}") {
					id
					name
					note
					image
					primaryLocation { id }
				}
			""")

		assert data["id"] == per.id
		assert data["name"] == per.name
		assert data["note"] == per.note
		assert data["image"] == nil
		assert data["primaryLocation"]["id"] == per.primary_location_id
	end

	test "as Agent with Organization concrete type", %{org: org} do
		assert %{data: %{"agent" => data}} =
			query!("""
				agent(id: "#{org.id}") {
					id
					name
					note
					image
					primaryLocation { id }
				}
			""")

		assert data["id"] == org.id
		assert data["name"] == org.name
		assert data["note"] == org.note
		assert data["image"] == nil
		assert data["primaryLocation"]["id"] == org.primary_location_id
	end

	test "as Person", %{per: per} do
		assert %{data: %{"agent" => data}} =
			query!("""
				agent(id: "#{per.id}") {
					... on Person {
						id
						name
						note
						image
						primaryLocation { id }
						user
						email
					}
				}
			""")

		assert data["id"] == per.id
		assert data["name"] == per.name
		assert data["note"] == per.note
		assert data["image"] == nil
		assert data["primaryLocation"]["id"] == per.primary_location_id

		assert data["user"] == per.user
		assert data["email"] == per.email
	end

	test "as Organization", %{org: org} do
		assert %{data: %{"agent" => data}} =
			query!("""
				agent(id: "#{org.id}") {
					... on Organization {
						id
						name
						note
						image
						primaryLocation { id }
						classifiedAs
					}
				}
			""")

		assert data["id"] == org.id
		assert data["name"] == org.name
		assert data["note"] == org.note
		assert data["image"] == nil
		assert data["primaryLocation"]["id"] == org.primary_location_id

		assert data["classifiedAs"] == org.classified_as
	end
end
end
