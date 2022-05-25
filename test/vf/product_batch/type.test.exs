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
