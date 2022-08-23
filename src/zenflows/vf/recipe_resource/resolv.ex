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

defmodule Zenflows.VF.RecipeResource.Resolv do
@moduledoc "Resolvers of RecipeResources."

alias Zenflows.VF.RecipeResource.Domain

def recipe_resource(params, _) do
	Domain.one(params)
end

def recipe_resources(params, _) do
	Domain.all(params)
end

def create_recipe_resource(%{recipe_resource: params}, _) do
	with {:ok, proc_spec} <- Domain.create(params) do
		{:ok, %{recipe_resource: proc_spec}}
	end
end

def update_recipe_resource(%{recipe_resource: %{id: id} = params}, _) do
	with {:ok, proc_spec} <- Domain.update(id, params) do
		{:ok, %{recipe_resource: proc_spec}}
	end
end

def delete_recipe_resource(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def unit_of_resource(rec_res, _, _) do
	rec_res = Domain.preload(rec_res, :unit_of_resource)
	{:ok, rec_res.unit_of_resource}
end

def unit_of_effort(rec_res, _, _) do
	rec_res = Domain.preload(rec_res, :unit_of_effort)
	{:ok, rec_res.unit_of_effort}
end

def resource_conforms_to(rec_res, _, _) do
	rec_res = Domain.preload(rec_res, :resource_conforms_to)
	{:ok, rec_res.resource_conforms_to}
end
end
