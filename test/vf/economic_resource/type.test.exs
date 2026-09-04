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

defmodule ZenflowsTest.VF.EconomicResource.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
			#"image" => Factory.img(),
		},
		inserted: Factory.insert!(:economic_resource),
	}
end

@frag """
fragment economicResource on EconomicResource {
	id
	name
	note
	#image
	trackingIdentifier
	classifiedAs
	conformsTo {id}
	accountingQuantity {
		hasUnit { id }
		hasNumericalValue
	}
	onhandQuantity {
		hasUnit { id }
		hasNumericalValue
	}
	primaryAccountable {id}
	custodian {id}
	stage {id}
	state {id}
	currentLocation {id}
	lot {id}
	containedIn {id}
	unitOfEffort {id}
	okhv
	repo
	version
	licensor
	license
	metadata
}
"""

describe "Query" do
	test "resource", %{inserted: new} do
		assert %{data: %{"economicResource" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					economicResource(id: $id) {...economicResource}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["note"] == new.note
		#assert data["image"] == new.image
		assert data["trackingIdentifier"] == new.tracking_identifier
		assert data["classifiedAs"] == new.classified_as
		assert data["conformsTo"]["id"] == new.conforms_to_id
		assert data["accountingQuantity"]["hasUnit"]["id"] == new.accounting_quantity_has_unit_id
		assert Decimal.eq?(data["accountingQuantity"]["hasNumericalValue"], new.accounting_quantity_has_numerical_value)
		assert data["onhandQuantity"]["hasUnit"]["id"] == new.onhand_quantity_has_unit_id
		assert Decimal.eq?(data["onhandQuantity"]["hasNumericalValue"], new.onhand_quantity_has_numerical_value)
		assert data["primaryAccountable"]["id"] == new.primary_accountable_id
		assert data["custodian"]["id"] == new.custodian_id
		assert data["stage"]["id"] == new.stage_id
		assert data["state"]["id"] == new.state_id
		assert data["currentLocation"]["id"] == new.current_location_id
		assert data["lot"]["id"] == new.lot_id
		assert data["containedIn"]["id"] == new.contained_in_id
		assert data["unitOfEffort"]["id"] == new.unit_of_effort_id
		assert data["okhv"] == new.okhv
		assert data["repo"] == new.repo
		assert data["version"] == new.version
		assert data["licensor"] == new.licensor
		assert data["license"] == new.license
		assert data["metadata"] == new.metadata
	end

	test "economicResources.pageInfo.totalCount reflects the whole filtered set, not just the page" do
		alias Ecto.Changeset
		alias Zenflows.DB.Repo

		%{id: agent_id} = Factory.insert!(:agent)

		Enum.each(1..5, fn _ ->
			Factory.insert!(:economic_resource)
			|> Changeset.change(primary_accountable_id: agent_id)
			|> Repo.update!()
		end)

		assert %{data: %{"economicResources" => data}} =
			run!("""
				query ($filter: EconomicResourceFilterParams! $first: Int!) {
					economicResources(filter: $filter first: $first) {
						pageInfo { totalCount pageLimit hasNextPage distinctPrimaryAccountableCount }
						edges { node { id } }
					}
				}
			""", vars: %{"filter" => %{"primaryAccountable" => [agent_id]}, "first" => 2})

		# only 2 edges come back for this page...
		assert length(data["edges"]) == 2
		assert data["pageInfo"]["pageLimit"] == 2
		assert data["pageInfo"]["hasNextPage"] == true
		# ...but totalCount and distinctPrimaryAccountableCount describe the
		# full filtered set of 5, not the page of 2.
		assert data["pageInfo"]["totalCount"] == 5
		assert data["pageInfo"]["distinctPrimaryAccountableCount"] == 1
	end
end

describe "Mutation" do
	@tag skip: "TODO: fix factory"
	test "updateEconomicResource", %{params: params, inserted: old} do
		assert %{data: %{"updateEconomicResource" => %{"economicResource" => data}}} =
			run!("""
				#{@frag}
				mutation ($resource: EconomicResourceUpdateParams!) {
					updateEconomicResource(resource: $resource) {
						economicResource {...economicResource}
					}
				}
			""", vars: %{"resource" => %{
				"id" => old.id,
				"note" => params["note"],
				#"image" => params["image"],
			}})

		assert data["id"] == old.id
		assert data["id"] == old.id
		assert data["name"] == old.name
		assert data["note"] == params["note"]
		#assert data["image"] == params["image"]
		assert data["trackingIdentifier"] == old.tracking_identifier
		assert data["classifiedAs"] == old.classified_as
		assert data["conformsTo"]["id"] == old.conforms_to_id
		assert data["accountingQuantity"]["hasUnit"]["id"] == old.accounting_quantity_has_unit_id
		assert data["accountingQuantity"]["hasNumericalValue"] == old.accounting_quantity_has_numerical_value
		assert data["onhandQuantity"]["hasUnit"]["id"] == old.onhand_quantity_has_unit_id
		assert data["onhandQuantity"]["hasNumericalValue"] == old.onhand_quantity_has_numerical_value
		assert data["primaryAccountable"]["id"] == old.primary_accountable_id
		assert data["custodian"]["id"] == old.custodian_id
		assert data["stage"]["id"] == old.stage_id
		assert data["state"]["id"] == old.state_id
		assert data["currentLocation"]["id"] == old.current_location_id
		assert data["lot"]["id"] == old.lot_id
		assert data["containedIn"]["id"] == old.contained_in_id
		assert data["unitOfEffort"]["id"] == old.unit_of_effort_id
	end

	@tag skip: "TODO: needs to deal with previous_event_id"
	test "deleteEconomicResource()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteEconomicResource" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteEconomicResource(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
