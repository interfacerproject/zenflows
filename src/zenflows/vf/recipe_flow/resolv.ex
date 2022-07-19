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

defmodule Zenflows.VF.RecipeFlow.Resolv do
@moduledoc "Resolvers of RecipeFlow."

use Absinthe.Schema.Notation

alias Zenflows.VF.{
	RecipeFlow,
	RecipeFlow.Domain,
}

def recipe_flow(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_recipe_flow(%{recipe_flow: params}, _info) do
	with {:ok, rec_flow} <- Domain.create(params) do
		{:ok, %{recipe_flow: rec_flow}}
	end
end

def update_recipe_flow(%{recipe_flow: %{id: id} = params}, _info) do
	with {:ok, rec_flow} <- Domain.update(id, params) do
		{:ok, %{recipe_flow: rec_flow}}
	end
end

def delete_recipe_flow(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def resource_quantity(%RecipeFlow{} = rec_flow, _args, _info) do
	rec_flow = Domain.preload(rec_flow, :resource_quantity)
	{:ok, rec_flow.resource_quantity}
end

def effort_quantity(%RecipeFlow{} = rec_flow, _args, _info) do
	rec_flow = Domain.preload(rec_flow, :effort_quantity)
	{:ok, rec_flow.effort_quantity}
end

def recipe_flow_resource(%RecipeFlow{} = rec_flow, _args, _info) do
	rec_flow = Domain.preload(rec_flow, :recipe_flow_resource)
	{:ok, rec_flow.recipe_flow_resource}
end

def action(%RecipeFlow{} = rec_flow, _args, _info) do
	rec_flow = Domain.preload(rec_flow, :action)
	{:ok, rec_flow.action}
end

def recipe_input_of(%RecipeFlow{} = rec_flow, _args, _info) do
	rec_flow = Domain.preload(rec_flow, :recipe_input_of)
	{:ok, rec_flow.recipe_input_of}
end

def recipe_output_of(%RecipeFlow{} = rec_flow, _args, _info) do
	rec_flow = Domain.preload(rec_flow, :recipe_output_of)
	{:ok, rec_flow.recipe_output_of}
end

def recipe_clause_of(%RecipeFlow{} = rec_flow, _args, _info) do
	rec_flow = Domain.preload(rec_flow, :recipe_clause_of)
	{:ok, rec_flow.recipe_clause_of}
end
end
