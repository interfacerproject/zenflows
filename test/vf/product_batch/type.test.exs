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

defmodule ZenflowsTest.VF.ProductBatch.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"batchNumber" => Factory.str("batch number"),
			"expiryDate" => Factory.iso_now(),
			"productionDate" => Factory.iso_now(),
		},
		inserted: Factory.insert!(:product_batch),
	}
end

@frag """
fragment productBatch on ProductBatch {
	id
	batchNumber
	expiryDate
	productionDate
}
"""

describe "Query" do
	test "productBatch", %{inserted: new} do
		assert %{data: %{"productBatch" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					productBatch(id: $id) {...productBatch}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["batchNumber"] == new.batch_number
		assert data["expiryDate"] == DateTime.to_iso8601(new.expiry_date)
		assert data["productionDate"] == DateTime.to_iso8601(new.production_date)
	end
end

describe "Mutation" do
	test "createProductBatch", %{params: params} do
		assert %{data: %{"createProductBatch" => %{"productBatch" => data}}} =
			run!("""
				#{@frag}
				mutation ($productBatch: ProductBatchCreateParams!) {
					createProductBatch(productBatch: $productBatch) {
						productBatch {...productBatch}
					}
				}
			""", vars: %{"productBatch" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		data = Map.delete(data, "id")
		assert data == params
	end

	test "updateProductBatch", %{params: params, inserted: old} do
		assert %{data: %{"updateProductBatch" => %{"productBatch" => data}}} =
			run!("""
				#{@frag}
				mutation ($productBatch: ProductBatchUpdateParams!) {
					updateProductBatch(productBatch: $productBatch) {
						productBatch {...productBatch}
					}
				}
			""", vars: %{"productBatch" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		data = Map.delete(data, "id")
		assert data == params
	end

	test "deleteProductBatch()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteProductBatch" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteProductBatch(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
