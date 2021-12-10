defmodule ZenflowsTest.Valflow.Agent.Type do
use ZenflowsTest.Case.Absin, async: true

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

	assert {:ok, _} = Zenflows.Ecto.Id.cast(data["id"])
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
