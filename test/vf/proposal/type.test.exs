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
	eligibleLocation {id}
}
"""
describe "Query" do
	test "proposal", %{inserted: prop} do
		assert %{data: %{"proposal" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					proposal(id: $id) {...proposal}
				}
			""", vars: %{"id" => prop.id})

		assert data["id"] == prop.id
		assert data["name"] == prop.name
		assert data["note"] == prop.note
		assert data["unitBased"] == prop.unit_based
		assert data["eligibleLocation"]["id"] == prop.eligible_location_id
		assert {:ok, has_beginning, 0} = DateTime.from_iso8601(data["hasBeginning"])
		assert DateTime.compare(DateTime.utc_now(), has_beginning) != :lt
		assert {:ok, has_end, 0} = DateTime.from_iso8601(data["hasEnd"])
		assert DateTime.compare(DateTime.utc_now(), has_end) != :lt
	end

	test "proposals" do
		assert %{data: %{"proposals" => data}} =
			run!("""
				#{@frag}
				query {
					proposals {
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
	end

	test "updateProposal", %{params: params, inserted: prop} do
		assert %{data: %{"updateProposal" => %{"proposal" => data}}} =
			run!("""
				#{@frag}
				mutation ($proposal: ProposalUpdateParams!) {
					updateProposal(proposal: $proposal) {
						proposal {...proposal}
					}
				}
			""", vars: %{"proposal" => params |> Map.put("id", prop.id)})

		assert data["id"] == prop.id
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
