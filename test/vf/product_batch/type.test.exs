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

defmodule ZenflowsTest.VF.ProductBatch.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			batch_number: Factory.uniq("batch number"),
			expiry_date: DateTime.utc_now(),
			production_date: DateTime.utc_now(),
		},
		inserted: Factory.insert!(:product_batch),
	}
end

describe "Query" do
	test "productBatch()", %{inserted: batch} do
		assert %{data: %{"productBatch" => data}} =
			query!("""
				productBatch(id: "#{batch.id}") {
					id
					batchNumber
					expiryDate
					productionDate
				}
			""")

		assert data["id"] == batch.id
		assert data["batchNumber"] == batch.batch_number
		assert data["expiryDate"] == DateTime.to_iso8601(batch.expiry_date)
		assert data["productionDate"] == DateTime.to_iso8601(batch.production_date)
	end
end

describe "Mutation" do
	test "createProductBatch()", %{params: params} do
		assert %{data: %{"createProductBatch" => %{"productBatch" => data}}} =
			mutation!("""
				createProductBatch(productBatch: {
					batchNumber: "#{params.batch_number}"
					expiryDate: "#{params.expiry_date}"
					productionDate: "#{params.production_date}"
				}) {
					productBatch {
						id
						batchNumber
						expiryDate
						productionDate
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["batchNumber"] == params.batch_number
		assert data["expiryDate"] == DateTime.to_iso8601(params.expiry_date)
		assert data["productionDate"] == DateTime.to_iso8601(params.production_date)
	end

	test "updateProductBatch()", %{params: params, inserted: batch} do
		assert %{data: %{"updateProductBatch" => %{"productBatch" => data}}} =
			mutation!("""
				updateProductBatch(productBatch: {
					id: "#{batch.id}"
					batchNumber: "#{params.batch_number}"
					expiryDate: "#{params.expiry_date}"
					productionDate: "#{params.production_date}"
				}) {
					productBatch {
						id
						batchNumber
						expiryDate
						productionDate
					}
				}
			""")

		assert data["id"] == batch.id
		assert data["batchNumber"] == params.batch_number
		assert data["expiryDate"] == DateTime.to_iso8601(params.expiry_date)
		assert data["productionDate"] == DateTime.to_iso8601(params.production_date)
	end

	test "deleteProductBatch()", %{inserted: %{id: id}} do
		assert %{data: %{"deleteProductBatch" => true}} =
			mutation!("""
				deleteProductBatch(id: "#{id}")
			""")
	end
end
end
