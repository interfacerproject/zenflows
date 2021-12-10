defmodule Zenflows.Valflow.RecipeResource.Resolv do
@moduledoc "Resolvers of RecipeResources."

alias Zenflows.Valflow.{
	RecipeResource,
	RecipeResource.Domain,
}

def recipe_resource(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_recipe_resource(%{recipe_resource: params}, _info) do
	with {:ok, proc_spec} <- Domain.create(params) do
		{:ok, %{recipe_resource: proc_spec}}
	end
end

def update_recipe_resource(%{recipe_resource: %{id: id} = params}, _info) do
	with {:ok, proc_spec} <- Domain.update(id, params) do
		{:ok, %{recipe_resource: proc_spec}}
	end
end

def delete_recipe_resource(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def unit_of_resource(%RecipeResource{} = rec_res, _args, _info) do
	rec_res = Domain.preload(rec_res, :unit_of_resource)
	{:ok, rec_res.unit_of_resource}
end

def unit_of_effort(%RecipeResource{} = rec_res, _args, _info) do
	rec_res = Domain.preload(rec_res, :unit_of_effort)
	{:ok, rec_res.unit_of_effort}
end

def resource_conforms_to(%RecipeResource{} = rec_res, _args, _info) do
	rec_res = Domain.preload(rec_res, :resource_conforms_to)
	{:ok, rec_res.resource_conforms_to}
end
end
