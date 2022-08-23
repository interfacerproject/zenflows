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
			"name" => Factory.str("name"),
			"resourceClassifiedAs" => Factory.str_list("uri"),
			"note" => Factory.str("note"),
			"image" => Factory.img(),
			"defaultUnitOfEffort" => Factory.insert!(:unit).id,
			"defaultUnitOfResource" => Factory.insert!(:unit).id,
		},
		inserted: Factory.insert!(:resource_specification),
	}
end

@frag """
fragment resourceSpecification on ResourceSpecification {
	id
	name
	resourceClassifiedAs
	defaultUnitOfResource {id}
	defaultUnitOfEffort {id}
	note
	image
}
"""

describe "Query" do
	test "resourceSpecification", %{inserted: new} do
		assert %{data: %{"resourceSpecification" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					resourceSpecification(id: $id) {...resourceSpecification}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["resourceClassifiedAs"] == new.resource_classified_as
		assert data["defaultUnitOfResource"]["id"] == new.default_unit_of_resource_id
		assert data["defaultUnitOfEffort"]["id"] == new.default_unit_of_effort_id
		assert data["note"] == new.note
		assert data["image"] == new.image
	end
end

describe "Mutation" do
	test "createResourceSpecification", %{params: params} do
		assert %{data: %{"createResourceSpecification" => %{"resourceSpecification" => data}}} =
			run!("""
				#{@frag}
				mutation ($resourceSpecification: ResourceSpecificationCreateParams!) {
					createResourceSpecification(resourceSpecification: $resourceSpecification) {
						resourceSpecification {...resourceSpecification}
					}
				}
			""", vars: %{"resourceSpecification" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		keys = ~w[name note resourceClassifiedAs note image]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["defaultUnitOfResource"]["id"] == params["defaultUnitOfResource"]
		assert data["defaultUnitOfEffort"]["id"] == params["defaultUnitOfEffort"]
	end

	test "updateResourceSpecification()", %{params: params, inserted: old} do
		assert %{data: %{"updateResourceSpecification" => %{"resourceSpecification" => data}}} =
			run!("""
				#{@frag}
				mutation ($resourceSpecification: ResourceSpecificationUpdateParams!) {
					updateResourceSpecification(resourceSpecification: $resourceSpecification) {
						resourceSpecification {...resourceSpecification}
					}
				}
			""", vars: %{"resourceSpecification" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		keys = ~w[name note resourceClassifiedAs note image]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["defaultUnitOfResource"]["id"] == params["defaultUnitOfResource"]
		assert data["defaultUnitOfEffort"]["id"] == params["defaultUnitOfEffort"]
	end

	test "deleteResourceSpecification()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteResourceSpecification" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteResourceSpecification(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
