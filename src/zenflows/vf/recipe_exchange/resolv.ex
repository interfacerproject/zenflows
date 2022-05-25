defmodule Zenflows.VF.RecipeExchange.Resolv do
@moduledoc "Resolvers of RecipeExchanges."

alias Zenflows.VF.RecipeExchange.Domain

def recipe_exchange(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_recipe_exchange(%{recipe_exchange: params}, _info) do
	with {:ok, rec_exch} <- Domain.create(params) do
		{:ok, %{recipe_exchange: rec_exch}}
	end
end

def update_recipe_exchange(%{recipe_exchange: %{id: id} = params}, _info) do
	with {:ok, rec_exch} <- Domain.update(id, params) do
		{:ok, %{recipe_exchange: rec_exch}}
	end
end

def delete_recipe_exchange(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
