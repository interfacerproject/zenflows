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

defmodule ZenflowsTest.VF.Proposal.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
			"hasBeginning" => Factory.iso_now(),
			"hasEnd" => Factory.iso_now(),
			"unitBased" => Factory.bool(),
			"eligibleLocation" => Factory.insert!(:spatial_thing).id,
		},
		inserted: Factory.insert!(:proposal),
	}
end

@frag """
fragment proposal on Proposal {
	id
	name
	note
	hasBeginning
	hasEnd
	unitBased
	created
	eligibleLocation {id}
}
"""

describe "Query" do
	test "proposal", %{inserted: new} do
		assert %{data: %{"proposal" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					proposal(id: $id) {...proposal}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
		assert data["unitBased"] == new.unit_based
		assert data["eligibleLocation"]["id"] == new.eligible_location_id
		assert {:ok, created, 0} = DateTime.from_iso8601(data["created"])
		assert DateTime.compare(DateTime.utc_now(), created) != :lt
		assert {:ok, has_beginning, 0} = DateTime.from_iso8601(data["hasBeginning"])
		assert DateTime.compare(DateTime.utc_now(), has_beginning) != :lt
		assert {:ok, has_end, 0} = DateTime.from_iso8601(data["hasEnd"])
		assert DateTime.compare(DateTime.utc_now(), has_end) != :lt
	end

	test "offers" do
		assert %{data: %{"offers" => data}} =
			run!("""
				#{@frag}
				query {
					offers {
						pageInfo {
							startCursor
							endCursor
							hasPreviousPage
							hasNextPage
							totalCount
							pageLimit
						}
						edges {
							cursor
							node {...proposal}
						}
					}
				}
			""")
		assert %{
			"pageInfo" => %{
				"startCursor" => nil,
				"endCursor" => nil,
				"hasPreviousPage" => false,
				"hasNextPage" => false,
				"totalCount" => nil,
				"pageLimit" => nil,
			},
			"edges" => [],
		} = data
	end

	test "requests" do
		assert %{data: %{"requests" => data}} =
			run!("""
				#{@frag}
				query {
					requests {
						pageInfo {
							startCursor
							endCursor
							hasPreviousPage
							hasNextPage
							totalCount
							pageLimit
						}
						edges {
							cursor
							node {...proposal}
						}
					}
				}
			""")
		assert %{
			"pageInfo" => %{
				"startCursor" => nil,
				"endCursor" => nil,
				"hasPreviousPage" => false,
				"hasNextPage" => false,
				"totalCount" => nil,
				"pageLimit" => nil,
			},
			"edges" => [],
		} = data
	end
end

describe "Mutation" do
	test "createProposal", %{params: params} do
		assert %{data: %{"createProposal" => %{"proposal" => data}}} =
			run!("""
				#{@frag}
				mutation ($proposal: ProposalCreateParams!) {
					createProposal(proposal: $proposal) {
						proposal {...proposal}
					}
				}
			""", vars: %{"proposal" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		keys = ~w[name note unitBased hasBeginning hasEnd]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["eligibleLocation"]["id"] == params["eligibleLocation"]
		assert {:ok, created, 0} = DateTime.from_iso8601(data["created"])
		assert DateTime.compare(DateTime.utc_now(), created) != :lt
	end

	test "updateProposal", %{params: params, inserted: old} do
		assert %{data: %{"updateProposal" => %{"proposal" => data}}} =
			run!("""
				#{@frag}
				mutation ($proposal: ProposalUpdateParams!) {
					updateProposal(proposal: $proposal) {
						proposal {...proposal}
					}
				}
			""", vars: %{"proposal" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		keys = ~w[name note unitBased hasBeginning hasEnd]
		assert Map.take(data, keys) == Map.take(params, keys)
		assert data["eligibleLocation"]["id"] == params["eligibleLocation"]
	end

	test "deleteProposal", %{inserted: %{id: id}} do
		assert %{data: %{"deleteProposal" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteProposal(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
