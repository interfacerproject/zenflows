defmodule Zenflows.VF.RecipeProcess.Resolv do
@moduledoc "Resolvers of RecipeProcess."

use Absinthe.Schema.Notation

alias Zenflows.VF.{RecipeProcess, RecipeProcess.Domain}

def recipe_process(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_recipe_process(%{recipe_process: params}, _info) do
	with {:ok, rec_proc} <- Domain.create(params) do
		{:ok, %{recipe_process: rec_proc}}
	end
end

def update_recipe_process(%{recipe_process: %{id: id} = params}, _info) do
	with {:ok, rec_proc} <- Domain.update(id, params) do
		{:ok, %{recipe_process: rec_proc}}
	end
end

def delete_recipe_process(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def has_duration(%RecipeProcess{} = rec_proc, _args, _info) do
	rec_proc = Domain.preload(rec_proc, :has_duration)
	{:ok, rec_proc.has_duration}
end

def process_conforms_to(%RecipeProcess{} = rec_proc, _args, _info) do
	rec_proc = Domain.preload(rec_proc, :process_conforms_to)
	{:ok, rec_proc.process_conforms_to}
end
end
