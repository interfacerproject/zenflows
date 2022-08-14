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
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		agreement: Factory.insert!(:agreement),
	}
end

describe "Query" do
	test "agreement()", %{agreement: agreem} do
		assert %{data: %{"agreement" => data}} =
			query!("""
				agreement(id: "#{agreem.id}") {
					id
					name
					note
					created
				}
			""")

		assert data["id"] == agreem.id
		assert data["name"] == agreem.name
		assert data["note"] == agreem.note
	end
end

describe "Mutation" do
	test "createAgreement()", %{params: params} do
		assert %{data: %{"createAgreement" => %{"agreement" => data}}} =
			mutation!("""
				createAgreement(agreement: {
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					agreement {
						id
						name
						note
						created
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
	end

	test "updateAgreement()", %{params: params, agreement: agreem} do
		assert %{data: %{"updateAgreement" => %{"agreement" => data}}} =
			mutation!("""
				updateAgreement(agreement: {
					id: "#{agreem.id}"
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					agreement {
						id
						name
						note
						created
					}
				}
			""")

		assert data["id"] == agreem.id
		assert data["name"] == params.name
		assert data["note"] == params.note
	end

	test "deleteAgreement()", %{agreement: %{id: id}} do
		assert %{data: %{"deleteAgreement" => true}} =
			mutation!("""
				deleteAgreement(id: "#{id}")
			""")
	end
end
end
