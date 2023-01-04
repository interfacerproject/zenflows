# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
			"primaryLocation" => Factory.insert!(:spatial_thing).id,
			"user" => Factory.str("user"),
			"email" => "#{Factory.str("user")}@example.com",
			"ecdhPublicKey" => Base.encode64("ecdh_public_key"),
			"eddsaPublicKey" => Base.encode64("eddsa_public_key"),
			"ethereumAddress" => Base.encode64("ethereum_address"),
			"reflowPublicKey" => Base.encode64("reflow_public_key"),
			"schnorrPublicKey" => Base.encode64("schnorr_public_key"),
		},
		inserted: Factory.insert!(:person),
	}
end

@frag """
fragment person on Person {
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
"""

describe "Query" do
	test "person", %{inserted: new} do
		assert %{data: %{"person" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					person(id: $id) {...person}
				}
			""", variables: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
		assert data["primaryLocation"]["id"] == new.primary_location_id

		assert data["user"] == new.user
		assert data["email"] == new.email
		assert data["ecdhPublicKey"] == new.ecdh_public_key
		assert data["eddsaPublicKey"] == new.eddsa_public_key
		assert data["ethereumAddress"] == new.ethereum_address
		assert data["reflowPublicKey"] == new.reflow_public_key
		assert data["schnorrPublicKey"] == new.schnorr_public_key
	end
end

describe "Mutation" do
	test "createPerson: doesn't create a person without the admin key", %{params: params} do
		assert %{data: nil, errors: [%{message: "you are not an admin", path: ["createPerson"]}]} =
			run!("""
				#{@frag}
				mutation ($person: PersonCreateParams!) {
					createPerson(person: $person) {
						agent {...person}
					}
				}
			""", auth?: true, vars: %{"person" => params})
	end

	test "createPerson: creates a person with the admin key", %{params: params} do
		assert %{data: %{"createPerson" => %{"agent" => data}}} =
			run!("""
				#{@frag}
				mutation ($person: PersonCreateParams!) {
					createPerson(person: $person) {
						agent {...person}
					}
				}
			""",
			auth?: true,
			ctx: %{gql_admin: admin_key()},
			vars: %{"person" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		data = Map.delete(data, "id")

		assert data["primaryLocation"]["id"] == params["primaryLocation"]
		data = Map.delete(data, "primaryLocation")
		params = Map.delete(params, "primaryLocation")

		assert data == params
	end

	test "updatePerson", %{params: params, inserted: old} do
		assert %{data: %{"updatePerson" => %{"agent" => data}}} =
			run!("""
				#{@frag}
				mutation ($person: PersonUpdateParams!) {
					updatePerson(person: $person) {
						agent {...person}
					}
				}
			""", vars: %{"person" =>
				params
				|> Map.take(~w[user name note primaryLocation])
				|> Map.put("id", old.id)
			})

		keys = ~w[user name note]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["primaryLocation"]["id"] == params["primaryLocation"]

		assert data["id"] == old.id
		assert data["email"] == old.email
		assert data["ecdhPublicKey"] == old.ecdh_public_key
		assert data["eddsaPublicKey"] == old.eddsa_public_key
		assert data["ethereumAddress"] == old.ethereum_address
		assert data["reflowPublicKey"] == old.reflow_public_key
		assert data["schnorrPublicKey"] == old.schnorr_public_key
	end

	test "deletePerson: doesn't delete the person without the admin key", %{inserted: new} do
		assert %{data: nil, errors: [%{message: "you are not an admin", path: ["deletePerson"]}]} =
			run!("""
				mutation ($id: ID!) {
					deletePerson(id: $id)
				}
			""", auth?: true, vars: %{"id" => new.id})
	end

	test "deletePerson: deletes the person with the admin key", %{inserted: new} do
		assert %{data: %{"deletePerson" => true}} =
			run!(
				"""
					mutation ($id: ID!) {
						deletePerson(id: $id)
					}
				""",
				auth?: true,
				ctx: %{gql_admin: admin_key()},
				vars: %{"id" => new.id})
	end

	defp admin_key() do
		Application.fetch_env!(:zenflows, Zenflows.Admin)[:admin_key]
		|> Base.encode16(case: :lower)
	end
end
end
