defmodule ZenflowsTest.Valflow.SpatialThing.Type do
use ZenflowsTest.Case.Absin, async: true

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

		assert {:ok, _} = Zenflows.Ecto.Id.cast(data["id"])
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
