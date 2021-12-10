defmodule ZenflowsTest.Valflow.ProductBatch do
use ZenflowsTest.Case.Repo, async: true

alias Zenflows.Valflow.ProductBatch

setup do
	%{params: %{
		batch_number: Factory.uniq("batch number"),
		expiry_date: DateTime.utc_now(),
		production_date: DateTime.utc_now(),
	}}
end

test "create ProductBatch", %{params: params} do
	assert {:ok, %ProductBatch{} = batch} =
		params
		|> ProductBatch.chset()
		|> Repo.insert()

	assert batch.batch_number == params.batch_number
	assert batch.expiry_date == params.expiry_date
	assert batch.production_date == params.production_date
end

test "update ProductBatch", %{params: params} do
	batch = Factory.insert!(:product_batch)

	assert {:ok, %ProductBatch{} = batch} =
		batch
		|> ProductBatch.chset(params)
		|> Repo.update()

	assert batch.batch_number == params.batch_number
	assert batch.expiry_date == params.expiry_date
	assert batch.production_date == params.production_date
end
end
