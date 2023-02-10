# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.RecipeExchange.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.RecipeExchange.Resolv

@name """
An informal or formal textual identifier for a recipe exchange.  Does not
imply uniqueness.
"""
@note "A textual description or comment."

@desc "Specifies an exchange agreement as part of a recipe."
object :recipe_exchange do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

input_object :recipe_exchange_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

input_object :recipe_exchange_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string
end

object :recipe_exchange_response do
	field :recipe_exchange, non_null(:recipe_exchange)
end

object :recipe_exchange_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:recipe_exchange)
end

object :recipe_exchange_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:recipe_exchange_edge)))
end

object :query_recipe_exchange do
	field :recipe_exchange, :recipe_exchange do
		arg :id, non_null(:id)
		resolve &Resolv.recipe_exchange/2
	end

	field :recipe_exchanges, :recipe_exchange_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.recipe_exchanges/2
	end
end

object :mutation_recipe_exchange do
	field :create_recipe_exchange, non_null(:recipe_exchange_response) do
		arg :recipe_exchange, non_null(:recipe_exchange_create_params)
		resolve &Resolv.create_recipe_exchange/2
	end

	field :update_recipe_exchange, non_null(:recipe_exchange_response) do
		arg :recipe_exchange, non_null(:recipe_exchange_update_params)
		resolve &Resolv.update_recipe_exchange/2
	end

	field :delete_recipe_exchange, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_recipe_exchange/2
	end
end
end
