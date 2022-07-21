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
			name: Factory.uniq("name"),
			# image
			note: Factory.uniq("note"),
			primary_location_id: Factory.insert!(:spatial_thing).id,
			user: Factory.uniq("user"),
			email: "#{Factory.uniq("user")}@example.com",
			ecdh_public_key: Base.encode64("ecdh_public_key"),
			eddsa_public_key: Base.encode64("eddsa_public_key"),
			ethereum_address: Base.encode64("ethereum_address"),
			reflow_public_key: Base.encode64("reflow_public_key"),
			schnorr_public_key: Base.encode64("schnorr_public_key"),
		},
		per: Factory.insert!(:person),
	}
end

describe "Query" do
	test "person()", %{per: per} do
		assert %{data: %{"person" => data}} =
			query!("""
				person(id: "#{per.id}") {
					id
					name
					note
					primaryLocation { id }
					user
					email
				}
			""")

		assert data["id"] == per.id
		assert data["name"] == per.name
		assert data["note"] == per.note
		assert data["primaryLocation"]["id"] == per.primary_location_id

		assert data["user"] == per.user
		assert data["email"] == per.email
	end
end

describe "Mutation" do
	test "createPerson() doesn't create a person without the admin key", %{params: params} do
		assert %{data: nil, errors: [%{message: "you are not authorized", path: ["createPerson"]}]} =
			mutation!("""
				createPerson(person: {
					name: "#{params.name}"
					note: "#{params.note}"
					primaryLocation: "#{params.primary_location_id}"
					user: "#{params.user}"
					email: "#{params.email}"
					ecdhPublicKey: "#{params.ecdh_public_key}"
					eddsaPublicKey: "#{params.eddsa_public_key}"
					ethereumAddress: "#{params.ethereum_address}"
					reflowPublicKey: "#{params.reflow_public_key}"
					schnorrPublicKey: "#{params.schnorr_public_key}"
				}) {
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
			""")
	end

	test "createPerson() creates a person with the admin key", %{params: params} do
		assert %{data: %{"createPerson" => %{"agent" => data}}} =
			mutation!("""
				createPerson(person: {
					name: "#{params.name}"
					note: "#{params.note}"
					primaryLocation: "#{params.primary_location_id}"
					user: "#{params.user}"
					email: "#{params.email}"
					ecdhPublicKey: "#{params.ecdh_public_key}"
					eddsaPublicKey: "#{params.eddsa_public_key}"
					ethereumAddress: "#{params.ethereum_address}"
					reflowPublicKey: "#{params.reflow_public_key}"
					schnorrPublicKey: "#{params.schnorr_public_key}"
				}) {
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
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["primaryLocation"]["id"] == params.primary_location_id
		assert data["user"] == params.user
		assert data["email"] == params.email
		assert data["ecdhPublicKey"] == params.ecdh_public_key
		assert data["eddsaPublicKey"] == params.eddsa_public_key
		assert data["ethereumAddress"] == params.ethereum_address
		assert data["reflowPublicKey"] == params.reflow_public_key
		assert data["schnorrPublicKey"] == params.schnorr_public_key
	end

	test "updatePerson()", %{params: params, per: per} do
		assert %{data: %{"updatePerson" => %{"agent" => data}}} =
			mutation!("""
				updatePerson(person: {
					id: "#{per.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					primaryLocation: "#{params.primary_location_id}"
					user: "#{params.user}"
				}) {
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
			""")

		assert data["id"] == per.id
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["primaryLocation"]["id"] == params.primary_location_id
		assert data["user"] == params.user
		assert data["email"] == per.email
		assert data["ecdhPublicKey"] == per.ecdh_public_key
		assert data["eddsaPublicKey"] == per.eddsa_public_key
		assert data["ethereumAddress"] == per.ethereum_address
		assert data["reflowPublicKey"] == per.reflow_public_key
		assert data["schnorrPublicKey"] == per.schnorr_public_key
	end

	test "deletePerson() doesn't delete the person without the admin key", %{per: per} do
		assert %{data: nil, errors: [%{message: "you are not authorized", path: ["deletePerson"]}]} =
			mutation!("""
				deletePerson(
					id: "#{per.id}"
				)
			""")
	end

	test "deletePerson() deletes the person with the admin key", %{per: per} do
		assert %{data: %{"deletePerson" => true}} =
			mutation!("""
				deletePerson(
					id: "#{per.id}"
				)
			""")
	end
end
end
