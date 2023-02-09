# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule ZenflowsTest.VF.ProposedIntent.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"reciprocal" => Factory.bool(),
			"publishedIn" => Factory.insert!(:proposal).id,
			"publishes" => Factory.insert!(:intent).id
		},
		inserted: Factory.insert!(:proposed_intent),
	}
end

describe "Mutation" do
	test "proposeIntent", %{params: params} do
		assert %{data: %{"proposeIntent" => %{"proposedIntent" => data}}} =
			run!("""
				mutation (
					$reciprocal: Boolean!
					$publishedIn: ID!
					$publishes: ID!
				) {
					proposeIntent(
						reciprocal: $reciprocal
						publishedIn: $publishedIn
						publishes: $publishes
					) {
						proposedIntent {
							id
							reciprocal
							publishedIn {id}
							publishes {id}
						}
					}
				}
			""", vars: params)

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["reciprocal"] == params["reciprocal"]
		assert data["publishedIn"]["id"] == params["publishedIn"]
		assert data["publishes"]["id"] == params["publishes"]
	end

	test "deleteProposedIntent", %{inserted: %{id: id}} do
		assert %{data: %{"deleteProposedIntent" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteProposedIntent(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
