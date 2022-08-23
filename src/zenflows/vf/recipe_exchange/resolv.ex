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

defmodule Zenflows.VF.RecipeExchange.Resolv do
@moduledoc "Resolvers of RecipeExchanges."

alias Zenflows.VF.RecipeExchange.Domain

def recipe_exchange(params, _) do
	Domain.one(params)
end

def recipe_exchanges(params, _) do
	Domain.all(params)
end

def create_recipe_exchange(%{recipe_exchange: params}, _) do
	with {:ok, rec_exch} <- Domain.create(params) do
		{:ok, %{recipe_exchange: rec_exch}}
	end
end

def update_recipe_exchange(%{recipe_exchange: %{id: id} = params}, _) do
	with {:ok, rec_exch} <- Domain.update(id, params) do
		{:ok, %{recipe_exchange: rec_exch}}
	end
end

def delete_recipe_exchange(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
