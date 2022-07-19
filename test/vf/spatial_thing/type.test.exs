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

defmodule ZenflowsTest.VF.SpatialThing.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			mappable_address: Factory.uniq("address"),
			lat: Factory.float(),
			long: Factory.float(),
			alt: Factory.float(),
			note: Factory.uniq("note"),
		},
		spatial_thing: Factory.insert!(:spatial_thing),
	}
end

describe "Query" do
	test "spatialThing()", %{spatial_thing: spt_thg} do
		assert %{data: %{"spatialThing" => data}} =
			query!("""
				spatialThing(id: "#{spt_thg.id}") {
					id
					name
					mappableAddress
					lat
					long
					alt
					note
				}
			""")

		assert data["id"] == spt_thg.id
		assert data["name"] == spt_thg.name
		assert data["mappableAddress"] == spt_thg.mappable_address
		assert data["lat"] == spt_thg.lat
		assert data["long"] == spt_thg.long
		assert data["alt"] == spt_thg.alt
		assert data["note"] == spt_thg.note
	end
end

describe "Mutation" do
	test "createSpatialThing()", %{params: params} do
		assert %{data: %{"createSpatialThing" => %{"spatialThing" => data}}} =
			mutation!("""
				createSpatialThing(spatialThing: {
					name: "#{params.name}"
					mappableAddress: "#{params.mappable_address}"
					lat: #{params.lat}
					long: #{params.long}
					alt: #{params.alt}
					note: "#{params.note}"
				}) {
					spatialThing {
						id
						name
						mappableAddress
						lat
						long
						alt
						note
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["mappableAddress"] == params.mappable_address
		assert data["lat"] == params.lat
		assert data["long"] == params.long
		assert data["alt"] == params.alt
		assert data["note"] == params.note
	end

	test "updateSpatialThing()", %{params: params, spatial_thing: spt_thg} do
		assert %{data: %{"updateSpatialThing" => %{"spatialThing" => data}}} =
			mutation!("""
				updateSpatialThing(spatialThing: {
					id: "#{spt_thg.id}"
					name: "#{params.name}"
					mappableAddress: "#{params.mappable_address}"
					lat: #{params.lat}
					long: #{params.long}
					alt: #{params.alt}
					note: "#{params.note}"
				}) {
					spatialThing {
						id
						name
						mappableAddress
						lat
						long
						alt
						note
					}
				}
			""")

		assert data["id"] == spt_thg.id
		assert data["name"] == params.name
		assert data["mappableAddress"] == params.mappable_address
		assert data["lat"] == params.lat
		assert data["long"] == params.long
		assert data["alt"] == params.alt
		assert data["note"] == params.note
	end

	test "deleteSpatialThing()", %{spatial_thing: %{id: id}} do
		assert %{data: %{"deleteSpatialThing" => true}} =
			mutation!("""
				deleteSpatialThing(id: "#{id}")
			""")
	end
end
end
