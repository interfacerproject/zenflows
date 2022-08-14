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

defmodule ZenflowsTest.VF.Agreement.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
		},
		inserted: Factory.insert!(:agreement),
	}
end

describe "Query" do
	test "agreement", %{inserted: agreem} do
		assert %{data: %{"agreement" => data}} =
			run!("""
				query ($id: ID!) {
					agreement(id: $id) {
						id
						name
						note
						created
					}
				}
			""", vars: %{"id" => agreem.id})

		assert data["id"] == agreem.id
		assert data["name"] == agreem.name
		assert data["note"] == agreem.note
		assert {:ok, created, 0} = DateTime.from_iso8601(data["created"])
		assert DateTime.compare(DateTime.utc_now(), created) != :lt
	end
end

describe "Mutation" do
	test "createAgreement", %{params: params} do
		assert %{data: %{"createAgreement" => %{"agreement" => data}}} =
			run!("""
				mutation ($name: String! $note: String!) {
					createAgreement(agreement: {
						name: $name
						note: $note
					}) {
						agreement {
							id
							name
							note
							created
						}
					}
				}
			""", vars: params)

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert Map.take(data, ~w[name note]) == params
		assert {:ok, created, 0} = DateTime.from_iso8601(data["created"])
		assert DateTime.compare(DateTime.utc_now(), created) != :lt
	end

	test "updateAgreement", %{params: params, inserted: agreem} do
		assert %{data: %{"updateAgreement" => %{"agreement" => data}}} =
			run!("""
				mutation (
					$id: ID!
					$name: String!
					$note: String!
				) {
					updateAgreement(agreement: {
						id: $id
						name: $name
						note: $note
					}) {
						agreement {
							id
							name
							note
							created
						}
					}
				}
			""", vars: params |> Map.put("id", agreem.id))

		assert data["id"] == agreem.id
		assert Map.take(data, ~w[name note]) == params
		assert {:ok, created, 0} = DateTime.from_iso8601(data["created"])
		assert DateTime.compare(DateTime.utc_now(), created) != :lt
	end

	test "deleteAgreement", %{inserted: %{id: id}} do
		assert %{data: %{"deleteAgreement" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteAgreement(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
