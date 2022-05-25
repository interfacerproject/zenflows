defmodule Zenflows.VF.ProductBatch.Resolv do
@moduledoc "Resolvers of ProductBatch."

use Absinthe.Schema.Notation

alias Zenflows.VF.ProductBatch.Domain

def product_batch(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_product_batch(%{product_batch: params}, _info) do
	with {:ok, batch} <- Domain.create(params) do
		{:ok, %{product_batch: batch}}
	end
end

def update_product_batch(%{product_batch: %{id: id} = params}, _info) do
	with {:ok, batch} <- Domain.update(id, params) do
		{:ok, %{product_batch: batch}}
	end
end

def delete_product_batch(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
