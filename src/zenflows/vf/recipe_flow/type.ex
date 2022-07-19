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

defmodule Zenflows.VF.RecipeFlow.Type do
@moduledoc "GraphQL types of RecipeFlows."

use Absinthe.Schema.Notation

alias Zenflows.VF.RecipeFlow.Resolv

@resource_quantity """
The amount and unit of the economic resource counted or inventoried.
"""
@effort_quantity """
The amount and unit of the work or use or citation effort-based
action.  This is often a time duration, but also could be cycle counts
or other measures of effort or usefulness.
"""
@recipe_flow_resource """
The resource definition referenced by this flow in the recipe.
"""
@action """
Relates a process input or output to a verb, such as consume, produce,
work, modify, etc.
"""
@recipe_input_of "Relates an input flow to its process in a recipe."
@recipe_output_of "Relates an output flow to its process in a recipe."
@recipe_clause_of "Relates a flow to its exchange agreement in a recipe."
@note "A textual description or comment."

@desc """
The specification of a resource inflow to, or outflow from,
a recipe process.
"""
object :recipe_flow do
	field :id, non_null(:id)

	@desc @resource_quantity
	field :resource_quantity, :measure,
		resolve: &Resolv.resource_quantity/3

	@desc @effort_quantity
	field :effort_quantity, :measure,
		resolve: &Resolv.effort_quantity/3

	@desc @recipe_flow_resource
	field :recipe_flow_resource, non_null(:recipe_resource),
		resolve: &Resolv.recipe_flow_resource/3

	@desc @action
	field :action, non_null(:action), resolve: &Resolv.action/3

	@desc @recipe_input_of
	field :recipe_input_of, :recipe_process,
		resolve: &Resolv.recipe_input_of/3

	@desc @recipe_output_of
	field :recipe_output_of, :recipe_process,
		resolve: &Resolv.recipe_output_of/3

	@desc @recipe_clause_of
	field :recipe_clause_of, :recipe_exchange,
		resolve: &Resolv.recipe_clause_of/3

	@desc @note
	field :note, :string
end

object :recipe_flow_response do
	field :recipe_flow, non_null(:recipe_flow)
end

input_object :recipe_flow_create_params do
	@desc @resource_quantity
	field :resource_quantity, :imeasure

	@desc @effort_quantity
	field :effort_quantity, :imeasure

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`RecipeResource`) " <> @recipe_flow_resource
	field :recipe_flow_resource_id, non_null(:id),
		name: "recipe_flow_resource"

	@desc "(`Action`) " <> @action
	field :action_id, non_null(:string), name: "action"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`RecipeProcess`) " <> @recipe_input_of
	field :recipe_input_of_id, :id, name: "recipe_input_of"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`RecipeProcess`) " <> @recipe_output_of
	field :recipe_output_of_id, :id, name: "recipe_output_of"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`RecipeExchange`) " <> @recipe_clause_of
	field :recipe_clause_of_id, :id, name: "recipe_clause_of"

	@desc @note
	field :note, :string
end

input_object :recipe_flow_update_params do
	field :id, non_null(:id)

	@desc @resource_quantity
	field :resource_quantity, :imeasure

	@desc @effort_quantity
	field :effort_quantity, :imeasure

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`RecipeResource`) " <> @recipe_flow_resource
	field :recipe_flow_resource_id, :id, name: "recipe_flow_resource"

	@desc "(`Action`) " <> @action
	field :action_id, :string, name: "action"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`RecipeProcess`) " <> @recipe_input_of
	field :recipe_input_of_id, :id, name: "recipe_input_of"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`RecipeProcess`) " <> @recipe_output_of
	field :recipe_output_of_id, :id, name: "recipe_output_of"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`RecipeExchange`) " <> @recipe_clause_of
	field :recipe_clause_of_id, :id, name: "recipe_clause_of"

	@desc @note
	field :note, :string
end

object :query_recipe_flow do
	field :recipe_flow, :recipe_flow do
		arg :id, non_null(:id)
		resolve &Resolv.recipe_flow/2
	end

	#recipeFlow(start: ID, limit: Int): [RecipeFlow!]
end

object :mutation_recipe_flow do
	field :create_recipe_flow, non_null(:recipe_flow_response) do
		arg :recipe_flow, non_null(:recipe_flow_create_params)
		resolve &Resolv.create_recipe_flow/2
	end

	field :update_recipe_flow, non_null(:recipe_flow_response) do
		arg :recipe_flow, non_null(:recipe_flow_update_params)
		resolve &Resolv.update_recipe_flow/2
	end

	field :delete_recipe_flow, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_recipe_flow/2
	end
end
end
