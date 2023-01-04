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

defmodule ZenflowsTest.VF.Intent.Type do
use ZenflowsTest.Help.AbsinCase, async: true

alias Zenflows.DB.ID

setup do
	%{
		params: %{
			"action" => Factory.build(:action_id),
			"inputOf" => Factory.insert!(:process).id,
			"outputOf" => Factory.insert!(:process).id,
			"provider" => Factory.insert!(:agent).id,
			"receiver" => Factory.insert!(:agent).id,
			"resourceInventoriedAs" => Factory.insert!(:economic_resource).id,
			"resourceConformsTo" => Factory.insert!(:resource_specification).id,
			"resourceClassifiedAs" => Factory.str_list("uri"),
			"resourceQuantity" => %{
				"hasUnit" => Factory.insert!(:unit).id,
				"hasNumericalValue" => Factory.decimal(),
			},
			"effortQuantity" => %{
				"hasUnit" => Factory.insert!(:unit).id,
				"hasNumericalValue" => Factory.decimal(),
			},
			"availableQuantity" => %{
				"hasUnit" => Factory.insert!(:unit).id,
				"hasNumericalValue" => Factory.decimal(),
			},
			"hasBeginning" => Factory.iso_now(),
			"hasEnd" => Factory.iso_now(),
			"hasPointInTime" => Factory.iso_now(),
			"due" => Factory.iso_now(),
			"finished" => Factory.bool(),
			"atLocation" => Factory.insert!(:spatial_thing).id,
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
			# inScopeOf:
			"agreedIn" => Factory.str("uri"),
		},
		inserted: Factory.insert!(:intent),
		id: Factory.id(),
	}
end

@frag """
fragment measure on Measure {
	hasNumericalValue
	hasUnit {id}
}

fragment intent on Intent {
	id
	action {id}
	inputOf {id}
	outputOf {id}
	provider {id}
	receiver {id}
	resourceInventoriedAs {id}
	resourceConformsTo {id}
	resourceClassifiedAs
	resourceQuantity {...measure}
	effortQuantity {...measure}
	availableQuantity {...measure}
	hasBeginning
	hasEnd
	hasPointInTime
	due
	finished
	atLocation {id}
	name
	note
	agreedIn
}
"""

describe "Query" do
	test "intent", %{inserted: int} do
		assert %{data: %{"intent" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					intent(id: $id) {...intent}
				}
			""", vars: %{"id" => int.id})

		assert data["id"] == int.id
		assert data["action"]["id"] == int.action_id
		assert data["inputOf"]["id"] == int.input_of_id
		assert data["outputOf"]["id"] == int.output_of_id
		assert data["provider"]["id"] == int.provider_id
		assert data["receiver"]["id"] == int.receiver_id
		assert data["resourceInventoriedAs"]["id"] == int.resource_inventoried_as_id
		assert data["resourceConformsTo"]["id"] == int.resource_conforms_to_id
		assert data["resourceClassifiedAs"] == int.resource_classified_as
		assert Decimal.eq?(data["resourceQuantity"]["hasNumericalValue"], int.resource_quantity_has_numerical_value)
		assert data["resourceQuantity"]["hasUnit"]["id"] == int.resource_quantity_has_unit_id
		assert Decimal.eq?(data["effortQuantity"]["hasNumericalValue"], int.effort_quantity_has_numerical_value)
		assert data["effortQuantity"]["hasUnit"]["id"] == int.effort_quantity_has_unit_id
		assert Decimal.eq?(data["availableQuantity"]["hasNumericalValue"], int.available_quantity_has_numerical_value)
		assert data["availableQuantity"]["hasUnit"]["id"] == int.available_quantity_has_unit_id
		assert data["hasBeginning"] == DateTime.to_iso8601(int.has_beginning)
		assert data["hasEnd"] == DateTime.to_iso8601(int.has_end)
		assert data["hasPointInTime"] == DateTime.to_iso8601(int.has_point_in_time)
		assert data["due"] == DateTime.to_iso8601(int.due)
		assert data["finished"] == int.finished
		assert data["atLocation"]["id"] == int.at_location_id
		assert data["name"] == int.name
		assert data["note"] == int.note
		assert data["agreedIn"] == int.agreed_in
	end
end

describe "Mutation" do
	test "createIntent with only provider", %{params: params} do
		params = Map.put(params, "receiver", nil)

		assert %{data: %{"createIntent" => %{"intent" => data}}} =
			run!("""
				#{@frag}
				mutation ($intent: IntentCreateParams!) {
					createIntent(intent: $intent) {
						intent {...intent}
					}
				}
			""", vars: %{"intent" => params})

		assert {:ok, _} = ID.cast(data["id"])
		assert data["action"]["id"] == params["action"]
		assert data["inputOf"]["id"] == params["inputOf"]
		assert data["outputOf"]["id"] == params["outputOf"]
		assert data["provider"]["id"] == params["provider"]
		assert data["receiver"]["id"] == params["receiver"]
		assert data["resourceInventoriedAs"]["id"] == params["resourceInventoriedAs"]
		assert data["resourceConformsTo"]["id"] == params["resourceConformsTo"]
		assert data["resourceClassifiedAs"] == params["resourceClassifiedAs"]
		assert data["resourceQuantity"]["hasNumericalValue"] == params["resourceQuantity"]["hasNumericalValue"]
		assert data["resourceQuantity"]["hasUnit"]["id"] == params["resourceQuantity"]["hasUnit"]
		assert data["effortQuantity"]["hasNumericalValue"] == params["effortQuantity"]["hasNumericalValue"]
		assert data["effortQuantity"]["hasUnit"]["id"] == params["effortQuantity"]["hasUnit"]
		assert data["availableQuantity"]["hasNumericalValue"] == params["availableQuantity"]["hasNumericalValue"]
		assert data["availableQuantity"]["hasUnit"]["id"] == params["availableQuantity"]["hasUnit"]
		assert data["atLocation"]["id"] == params["atLocation"]

		Enum.each(~w[
				hasBeginning hasEnd hasPointInTime due
				finished name note agreedIn
			], fn x ->
				assert data[x] == params[x]
			end)
	end

	test "createIntent with only receiver", %{params: params} do
		params = Map.put(params, "provider", nil)

		assert %{data: %{"createIntent" => %{"intent" => data}}} =
			run!("""
				#{@frag}
				mutation ($intent: IntentCreateParams!) {
					createIntent(intent: $intent) {
						intent {...intent}
					}
				}
			""", vars: %{"intent" => params})

		assert {:ok, _} = ID.cast(data["id"])
		assert data["action"]["id"] == params["action"]
		assert data["inputOf"]["id"] == params["inputOf"]
		assert data["outputOf"]["id"] == params["outputOf"]
		assert data["provider"]["id"] == params["provider"]
		assert data["receiver"]["id"] == params["receiver"]
		assert data["resourceInventoriedAs"]["id"] == params["resourceInventoriedAs"]
		assert data["resourceConformsTo"]["id"] == params["resourceConformsTo"]
		assert data["resourceClassifiedAs"] == params["resourceClassifiedAs"]
		assert data["resourceQuantity"]["hasNumericalValue"] == params["resourceQuantity"]["hasNumericalValue"]
		assert data["resourceQuantity"]["hasUnit"]["id"] == params["resourceQuantity"]["hasUnit"]
		assert data["effortQuantity"]["hasNumericalValue"] == params["effortQuantity"]["hasNumericalValue"]
		assert data["effortQuantity"]["hasUnit"]["id"] == params["effortQuantity"]["hasUnit"]
		assert data["availableQuantity"]["hasNumericalValue"] == params["availableQuantity"]["hasNumericalValue"]
		assert data["availableQuantity"]["hasUnit"]["id"] == params["availableQuantity"]["hasUnit"]
		assert data["atLocation"]["id"] == params["atLocation"]

		Enum.each(~w[
				hasBeginning hasEnd hasPointInTime due
				finished name note agreedIn
			], fn x ->
				assert data[x] == params[x]
			end)
	end

	test "updateIntent with only provider", %{params: params} do
		params = Map.put(params, "receiver", nil)
		%{id: id} = Factory.insert!(:intent, %{provider: Factory.build(:agent), receiver: nil})
		assert %{data: %{"updateIntent" => %{"intent" => data}}} =
			run!("""
				#{@frag}
				mutation ($intent: IntentUpdateParams!) {
					updateIntent(intent: $intent) {
						intent {...intent}
					}
				}
			""", vars: %{
				"intent" => Map.put(params, "id", id),
			})

		assert data["id"] == id
		assert data["action"]["id"] == params["action"]
		assert data["inputOf"]["id"] == params["inputOf"]
		assert data["outputOf"]["id"] == params["outputOf"]
		assert data["provider"]["id"] == params["provider"]
		assert data["receiver"]["id"] == params["receiver"]
		assert data["resourceInventoriedAs"]["id"] == params["resourceInventoriedAs"]
		assert data["resourceConformsTo"]["id"] == params["resourceConformsTo"]
		assert data["resourceClassifiedAs"] == params["resourceClassifiedAs"]
		assert data["resourceQuantity"]["hasNumericalValue"] == params["resourceQuantity"]["hasNumericalValue"]
		assert data["resourceQuantity"]["hasUnit"]["id"] == params["resourceQuantity"]["hasUnit"]
		assert data["effortQuantity"]["hasNumericalValue"] == params["effortQuantity"]["hasNumericalValue"]
		assert data["effortQuantity"]["hasUnit"]["id"] == params["effortQuantity"]["hasUnit"]
		assert data["availableQuantity"]["hasNumericalValue"] == params["availableQuantity"]["hasNumericalValue"]
		assert data["availableQuantity"]["hasUnit"]["id"] == params["availableQuantity"]["hasUnit"]
		assert data["atLocation"]["id"] == params["atLocation"]

		Enum.each(~w[
				hasBeginning hasEnd hasPointInTime due
				finished name note agreedIn
			], fn x ->
				assert data[x] == params[x]
			end)
	end

	test "updateIntent with only receiver", %{params: params} do
		params = Map.put(params, "provider", nil)
		%{id: id} = Factory.insert!(:intent, %{provider: nil, receiver: Factory.build(:agent)})
		assert %{data: %{"updateIntent" => %{"intent" => data}}} =
			run!("""
				#{@frag}
				mutation ($intent: IntentUpdateParams!) {
					updateIntent(intent: $intent) {
						intent {...intent}
					}
				}
			""", vars: %{
				"intent" => Map.put(params, "id", id),
			})

		assert data["id"] == id
		assert data["action"]["id"] == params["action"]
		assert data["inputOf"]["id"] == params["inputOf"]
		assert data["outputOf"]["id"] == params["outputOf"]
		assert data["provider"]["id"] == params["provider"]
		assert data["receiver"]["id"] == params["receiver"]
		assert data["resourceInventoriedAs"]["id"] == params["resourceInventoriedAs"]
		assert data["resourceConformsTo"]["id"] == params["resourceConformsTo"]
		assert data["resourceClassifiedAs"] == params["resourceClassifiedAs"]
		assert data["resourceQuantity"]["hasNumericalValue"] == params["resourceQuantity"]["hasNumericalValue"]
		assert data["resourceQuantity"]["hasUnit"]["id"] == params["resourceQuantity"]["hasUnit"]
		assert data["effortQuantity"]["hasNumericalValue"] == params["effortQuantity"]["hasNumericalValue"]
		assert data["effortQuantity"]["hasUnit"]["id"] == params["effortQuantity"]["hasUnit"]
		assert data["availableQuantity"]["hasNumericalValue"] == params["availableQuantity"]["hasNumericalValue"]
		assert data["availableQuantity"]["hasUnit"]["id"] == params["availableQuantity"]["hasUnit"]
		assert data["atLocation"]["id"] == params["atLocation"]

		Enum.each(~w[
				hasBeginning hasEnd hasPointInTime due
				finished name note agreedIn
			], fn x ->
				assert data[x] == params[x]
			end)
	end

	test "deleteIntent", %{inserted: %{id: id}} do
		assert %{data: %{"deleteIntent" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteIntent(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
