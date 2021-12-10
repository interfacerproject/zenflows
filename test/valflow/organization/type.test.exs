defmodule ZenflowsTest.Valflow.Organization.Type do
use ZenflowsTest.Case.Absin, async: true

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

# TODO: Uncomment :primary_location related logic when the bug in Absinthe
# gets fixed.
describe "Mutation" do
	test "createOrganization", %{params: params} do
		assert %{data: %{"createOrganization" => %{"agent" => data}}} =
			mutation!("""
				createOrganization(organization: {
					name: "#{params.name}"
					note: "#{params.note}"
					#primaryLocation: "#{params.primary_location_id}"
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

		assert {:ok, _} = Zenflows.Ecto.Id.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
		#assert data["primaryLocation"]["id"] == params.primary_location_id
		assert data["classifiedAs"] == params.classified_as
	end

	test "updateOrganization()", %{params: params, org: org} do
		assert %{data: %{"updateOrganization" => %{"agent" => data}}} =
			mutation!("""
				updateOrganization(organization: {
					id: "#{org.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					#primaryLocation: "#{params.primary_location_id}"
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
		#assert data["primaryLocation"]["id"] == params.primary_location_id
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
