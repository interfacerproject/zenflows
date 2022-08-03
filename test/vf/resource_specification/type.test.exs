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

defmodule ZenflowsTest.VF.ResourceSpecification.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.uniq("name"),
			"resourceClassifiedAs" => Factory.uniq_list("uri"),
			"note" => Factory.uniq("note"),
			"image" => Factory.img(),
			"defaultUnitOfEffort" => Factory.insert!(:unit).id,
			"defaultUnitOfResource" => Factory.insert!(:unit).id,
		},
		resource_specification: Factory.insert!(:resource_specification),
	}
end

describe "Query" do
	test "resourceSpecification()", %{resource_specification: res_spec} do
		assert %{data: %{"resourceSpecification" => data}} =
			run!("""
				query ($id: ID!) {
					resourceSpecification(id: $id) {
						id
						name
						resourceClassifiedAs
						defaultUnitOfResource { id }
						defaultUnitOfEffort { id }
						note
						image
					}
				}
			""", vars: %{"id" => res_spec.id})

		assert data["id"] == res_spec.id
		assert data["name"] == res_spec.name
		assert data["resourceClassifiedAs"] == res_spec.resource_classified_as
		assert data["defaultUnitOfResource"]["id"] == res_spec.default_unit_of_resource_id
		assert data["defaultUnitOfEffort"]["id"] == res_spec.default_unit_of_effort_id
		assert data["note"] == res_spec.note
		assert data["image"] == res_spec.image
	end
end

describe "Mutation" do
	test "createResourceSpecification()", %{params: params} do
		assert %{data: %{"createResourceSpecification" => %{"resourceSpecification" => data}}} =
			run!("""
				mutation ($resourceSpecification: ResourceSpecificationCreateParams!) {
					createResourceSpecification(resourceSpecification: $resourceSpecification) {
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
				}
			""", vars: %{"resourceSpecification" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		keys = ~w[name note resourceClassifiedAs note image]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["defaultUnitOfResource"]["id"] == params["defaultUnitOfResource"]
		assert data["defaultUnitOfEffort"]["id"] == params["defaultUnitOfEffort"]
	end

	test "updateResourceSpecification()", %{params: params, resource_specification: res_spec} do
		assert %{data: %{"updateResourceSpecification" => %{"resourceSpecification" => data}}} =
			run!("""
				mutation ($resourceSpecification: ResourceSpecificationUpdateParams!) {
					updateResourceSpecification(resourceSpecification: $resourceSpecification) {
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
				}
			""", vars: %{"resourceSpecification" =>
				Map.put(params, "id", res_spec.id),
			})

		assert data["id"] == res_spec.id
		keys = ~w[name note resourceClassifiedAs note image]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["defaultUnitOfResource"]["id"] == params["defaultUnitOfResource"]
		assert data["defaultUnitOfEffort"]["id"] == params["defaultUnitOfEffort"]
	end

	test "deleteResourceSpecification()", %{resource_specification: %{id: id}} do
		assert %{data: %{"deleteResourceSpecification" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteResourceSpecification(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
