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

defmodule ZenflowsTest.VF.EconomicResource.Type do
use ZenflowsTest.Help.AbsinCase, async: true

alias Zenflows.VF.EconomicResource.Domain

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			image: Factory.uri(),
		},
		inserted:
			Factory.insert!(:economic_resource)
			|> Domain.preload(:accounting_quantity)
			|> Domain.preload(:onhand_quantity)
	}
end

describe "Query" do
	@tag skip: "TODO: fix economic resource factory"
	test "resource()", %{inserted: eco_res} do
		assert %{data: %{"economicResource" => data}} =
			query!("""
				economicResource(id: "#{eco_res.id}") {
					id
					name
					note
					image
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
				}
			""")

		assert data["id"] == eco_res.id
		assert data["name"] == eco_res.name
		assert data["note"] == eco_res.note
		# virtual field atm
		# assert data["image"] == eco_res.image
		assert data["trackingIdentifier"] == eco_res.tracking_identifier
		assert data["classifiedAs"] == eco_res.classified_as
		assert data["conformsTo"]["id"] == eco_res.conforms_to_id
		assert data["accountingQuantity"]["hasUnit"]["id"] == eco_res.accounting_quantity_has_unit_id
		assert data["accountingQuantity"]["hasNumericalValue"] == eco_res.accounting_quantity_has_numerical_value
		assert data["onhandQuantity"]["hasUnit"]["id"] == eco_res.onhand_quantity_has_unit_id
		assert data["onhandQuantity"]["hasNumericalValue"] == eco_res.onhand_quantity_has_numerical_value
		assert data["primaryAccountable"]["id"] == eco_res.primary_accountable_id
		assert data["custodian"]["id"] == eco_res.custodian_id
		assert data["stage"]["id"] == eco_res.stage_id
		assert data["state"]["id"] == eco_res.state_id
		assert data["currentLocation"]["id"] == eco_res.current_location_id
		assert data["lot"]["id"] == eco_res.lot_id
		assert data["containedIn"]["id"] == eco_res.contained_in_id
		assert data["unitOfEffort"]["id"] == eco_res.unit_of_effort_id
	end
end

describe "Mutation" do
	@tag skip: "TODO: fix economic resource factory"
	test "updateEconomicResource()", %{params: params, inserted: eco_res} do
		assert %{data: %{"updateEconomicResource" => %{"economicResource" => data}}} =
			mutation!("""
				updateEconomicResource(resource: {
					id: "#{eco_res.id}"
					note: "#{params.note}"
					image: "#{params.image}"
				}) {
					economicResource {
						id
						name
						note
						image
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
					}
				}
			""")

		assert data["id"] == eco_res.id
		assert data["id"] == eco_res.id
		assert data["name"] == eco_res.name
		assert data["note"] == params.note
		# virtual field atm
		# assert data["image"] == eco_res.image
		assert data["trackingIdentifier"] == eco_res.tracking_identifier
		assert data["classifiedAs"] == eco_res.classified_as
		assert data["conformsTo"]["id"] == eco_res.conforms_to_id
		assert data["accountingQuantity"]["hasUnit"]["id"] == eco_res.accounting_quantity_has_unit_id
		assert data["accountingQuantity"]["hasNumericalValue"] == eco_res.accounting_quantity_has_numerical_value
		assert data["onhandQuantity"]["hasUnit"]["id"] == eco_res.onhand_quantity_has_unit_id
		assert data["onhandQuantity"]["hasNumericalValue"] == eco_res.onhand_quantity_has_numerical_value
		assert data["primaryAccountable"]["id"] == eco_res.primary_accountable_id
		assert data["custodian"]["id"] == eco_res.custodian_id
		assert data["stage"]["id"] == eco_res.stage_id
		assert data["state"]["id"] == eco_res.state_id
		assert data["currentLocation"]["id"] == eco_res.current_location_id
		assert data["lot"]["id"] == eco_res.lot_id
		assert data["containedIn"]["id"] == eco_res.contained_in_id
		assert data["unitOfEffort"]["id"] == eco_res.unit_of_effort_id
	end

	@tag skip: "TODO: fix economic resource factory"
	test "deleteEconomicResource()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteEconomicResource" => true}} =
			mutation!("""
				deleteEconomicResource(id: "#{id}")
			""")
	end
end
end
