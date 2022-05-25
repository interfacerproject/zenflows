defmodule ZenflowsTest.VF.ResourceSpecification.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			resource_classified_as: Factory.uniq_list("uri"),
			note: Factory.uniq("note"),
			image: Factory.uri(),
			default_unit_of_effort_id: Factory.insert!(:unit).id,
			default_unit_of_resource_id: Factory.insert!(:unit).id,
		},
		resource_specification: Factory.insert!(:resource_specification),
	}
end

describe "Query" do
	test "resourceSpecification()", %{resource_specification: res_spec} do
		assert %{data: %{"resourceSpecification" => data}} =
			query!("""
				resourceSpecification(id: "#{res_spec.id}") {
					id
					name
					resourceClassifiedAs
					defaultUnitOfResource { id }
					defaultUnitOfEffort { id }
					note
					image
				}
			""")

		assert data["id"] == res_spec.id
		assert data["name"] == res_spec.name
		assert data["resourceClassifiedAs"] == res_spec.resource_classified_as
		assert data["defaultUnitOfResource"]["id"] == res_spec.default_unit_of_resource_id
		assert data["defaultUnitOfEffort"]["id"] == res_spec.default_unit_of_effort_id
		assert data["note"] == res_spec.note
		assert data["image"] == nil
	end
end

describe "Mutation" do
	test "createResourceSpecification()", %{params: params} do
		assert %{data: %{"createResourceSpecification" => %{"resourceSpecification" => data}}} =
			mutation!("""
				createResourceSpecification(resourceSpecification: {
					name: "#{params.name}"
					resourceClassifiedAs: #{inspect(params.resource_classified_as)}
					defaultUnitOfResource: "#{params.default_unit_of_resource_id}"
					defaultUnitOfEffort: "#{params.default_unit_of_effort_id}"
					note: "#{params.note}"
					image: "#{params.image}"
				}) {
					resourceSpecification {
						id
						name
						resourceClassifiedAs
						defaultUnitOfResource { id }
						defaultUnitOfEffort { id }
						note
						image
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["resourceClassifiedAs"] == params.resource_classified_as
		assert data["defaultUnitOfResource"]["id"] == params.default_unit_of_resource_id
		assert data["defaultUnitOfEffort"]["id"] == params.default_unit_of_effort_id
		assert data["note"] == params.note
		assert data["image"] == params.image
	end

	test "updateResourceSpecification()", %{params: params, resource_specification: res_spec} do
		assert %{data: %{"updateResourceSpecification" => %{"resourceSpecification" => data}}} =
			mutation!("""
				updateResourceSpecification(resourceSpecification: {
					id: "#{res_spec.id}"
					name: "#{params.name}"
					resourceClassifiedAs: #{inspect(params.resource_classified_as)}
					defaultUnitOfResource: "#{params.default_unit_of_resource_id}"
					defaultUnitOfEffort: "#{params.default_unit_of_effort_id}"
					note: "#{params.note}"
					image: "#{params.image}"
				}) {
					resourceSpecification {
						id
						name
						resourceClassifiedAs
						defaultUnitOfResource { id }
						defaultUnitOfEffort { id }
						note
						image
					}
				}
			""")

		assert data["id"] == res_spec.id
		assert data["name"] == params.name
		assert data["resourceClassifiedAs"] == params.resource_classified_as
		assert data["defaultUnitOfResource"]["id"] == params.default_unit_of_resource_id
		assert data["defaultUnitOfEffort"]["id"] == params.default_unit_of_effort_id
		assert data["note"] == params.note
		assert data["image"] == params.image
	end

	test "deleteResourceSpecification()", %{resource_specification: %{id: id}} do
		assert %{data: %{"deleteResourceSpecification" => true}} =
			mutation!("""
				deleteResourceSpecification(id: "#{id}")
			""")
	end
end
end
