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

defmodule ZenflowsTest.VF.Person.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.uniq("name"),
			"image" => Factory.img(),
			"note" => Factory.uniq("note"),
			"primaryLocation" => Factory.insert!(:spatial_thing).id,
			"user" => Factory.uniq("user"),
			"email" => "#{Factory.uniq("user")}@example.com",
			"ecdhPublicKey" => Base.encode64("ecdh_public_key"),
			"eddsaPublicKey" => Base.encode64("eddsa_public_key"),
			"ethereumAddress" => Base.encode64("ethereum_address"),
			"reflowPublicKey" => Base.encode64("reflow_public_key"),
			"schnorrPublicKey" => Base.encode64("schnorr_public_key"),
		},
		per: Factory.insert!(:person),
	}
end

describe "Query" do
	test "person()", %{per: per} do
		assert %{data: %{"person" => data}} =
			run!("""
				query ($id: ID!) {
					person(id: $id) {
						id
						name
						note
						image
						primaryLocation { id }
						user
						email
						ecdhPublicKey
						eddsaPublicKey
						ethereumAddress
						reflowPublicKey
						schnorrPublicKey
					}
				}
			""", variables: %{"id" => per.id})

		assert data["id"] == per.id
		assert data["name"] == per.name
		assert data["note"] == per.note
		assert data["image"] == per.image
		assert data["primaryLocation"]["id"] == per.primary_location_id

		assert data["user"] == per.user
		assert data["email"] == per.email
		assert data["ecdhPublicKey"] == per.ecdh_public_key
		assert data["eddsaPublicKey"] == per.eddsa_public_key
		assert data["ethereumAddress"] == per.ethereum_address
		assert data["reflowPublicKey"] == per.reflow_public_key
		assert data["schnorrPublicKey"] == per.schnorr_public_key
	end
end

describe "Mutation" do
	test "createPerson() doesn't create a person without the admin key", %{params: params} do
		assert %{data: nil, errors: [%{message: "you are not an admin", path: ["createPerson"]}]} =
			run!("""
				mutation ($person: PersonCreateParams!) {
					createPerson(person: $person) {
						agent {
							id
							name
							note
							primaryLocation { id }
							user
							email
							ecdhPublicKey
							eddsaPublicKey
							ethereumAddress
							reflowPublicKey
							schnorrPublicKey
						}
					}
				}
			""", auth?: true, vars: %{"person" => params})
	end

	test "createPerson() creates a person with the admin key", %{params: params} do
		assert %{data: %{"createPerson" => %{"agent" => data}}} =
			run!("""
				mutation ($person: PersonCreateParams!) {
					createPerson(person: $person) {
						agent {
							id
							name
							note
							primaryLocation { id }
							user
							email
							image
							ecdhPublicKey
							eddsaPublicKey
							ethereumAddress
							reflowPublicKey
							schnorrPublicKey
						}
					}
				}
			""", vars: %{"person" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		data = Map.delete(data, "id")

		assert data["primaryLocation"]["id"] == params["primaryLocation"]
		data = Map.delete(data, "primaryLocation")
		params = Map.delete(params, "primaryLocation")

		assert data == params
	end

	test "updatePerson()", %{params: params, per: per} do
		assert %{data: %{"updatePerson" => %{"agent" => data}}} =
			run!("""
				mutation ($person: PersonUpdateParams!) {
					updatePerson(person: $person) {
						agent {
							id
							name
							note
							primaryLocation { id }
							user
							email
							image
							ecdhPublicKey
							eddsaPublicKey
							ethereumAddress
							reflowPublicKey
							schnorrPublicKey
						}
					}
				}
			""", vars: %{"person" =>
				params
				|> Map.take(~w[user name image note primaryLocation])
				|> Map.put("id", per.id)
			})

		keys = ~w[user name image note]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["primaryLocation"]["id"] == params["primaryLocation"]

		assert data["id"] == per.id
		assert data["email"] == per.email
		assert data["ecdhPublicKey"] == per.ecdh_public_key
		assert data["eddsaPublicKey"] == per.eddsa_public_key
		assert data["ethereumAddress"] == per.ethereum_address
		assert data["reflowPublicKey"] == per.reflow_public_key
		assert data["schnorrPublicKey"] == per.schnorr_public_key
	end

	test "deletePerson() doesn't delete the person without the admin key", %{per: per} do
		assert %{data: nil, errors: [%{message: "you are not an admin", path: ["deletePerson"]}]} =
			run!("""
				mutation ($id: ID!) {
					deletePerson(id: $id)
				}
			""", auth?: true, vars: %{"id" => per.id})
	end

	test "deletePerson() deletes the person with the admin key", %{per: per} do
		key =
			Application.fetch_env!(:zenflows, Zenflows.Admin)[:admin_key]
			|> Base.encode16(case: :lower)

		assert %{data: %{"deletePerson" => true}} =
			run!(
				"""
					mutation ($id: ID!) {
						deletePerson(id: $id)
					}
				""",
				auth?: true,
				vars: %{"id" => per.id},
				ctx: %{gql_admin: key}
			)
	end
end
end
