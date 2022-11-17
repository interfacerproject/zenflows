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
			"name" => Factory.str("name"),
			"mappableAddress" => Factory.str("address"),
			"lat" => Factory.decimal(),
			"long" => Factory.decimal(),
			"alt" => Factory.decimal(),
			"note" => Factory.str("note"),
		},
		inserted: Factory.insert!(:spatial_thing),
	}
end

@frag """
fragment spatialThing on SpatialThing {
	id
	name
	mappableAddress
	lat
	long
	alt
	note
}
"""

describe "Query" do
	test "spatialThing", %{inserted: new} do
		assert %{data: %{"spatialThing" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					spatialThing(id: $id) {...spatialThing}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["mappableAddress"] == new.mappable_address
		assert Decimal.eq?(data["lat"], new.lat)
		assert Decimal.eq?(data["long"], new.long)
		assert Decimal.eq?(data["alt"], new.alt)
		assert data["note"] == new.note
	end
end

describe "Mutation" do
	test "createSpatialThing", %{params: params} do
		assert %{data: %{"createSpatialThing" => %{"spatialThing" => data}}} =
			run!("""
				#{@frag}
				mutation ($spatialThing: SpatialThingCreateParams!) {
					createSpatialThing(spatialThing: $spatialThing) {
						spatialThing {...spatialThing}
					}
				}
			""", vars: %{"spatialThing" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		data = Map.delete(data, "id")
		assert data == params
	end

	test "updateSpatialThing", %{params: params, inserted: old} do
		assert %{data: %{"updateSpatialThing" => %{"spatialThing" => data}}} =
			run!("""
				#{@frag}
				mutation ($spatialThing: SpatialThingUpdateParams!) {
					updateSpatialThing(spatialThing: $spatialThing) {
						spatialThing {...spatialThing}
					}
				}
			""", vars: %{"spatialThing" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		data = Map.delete(data, "id")
		assert data == params
	end

	test "deleteSpatialThing", %{inserted: %{id: id}} do
		assert %{data: %{"deleteSpatialThing" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteSpatialThing(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
