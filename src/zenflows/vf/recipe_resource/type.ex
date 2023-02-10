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

defmodule Zenflows.VF.RecipeResource.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.RecipeResource.Resolv

@name """
An informal or formal textual identifier for a recipe resource.  Does not
imply uniqueness.
"""
@image """
The base64-encoded image binary relevant to the entity, such as a photo, diagram, etc.
"""
@unit_of_resource """
The unit of inventory used for this resource in the recipe.
"""
@unit_of_resource_id "(`Unit`) #{@unit_of_resource}"
@unit_of_effort """
The unit used for use action on this resource or work action in the
recipe.
"""
@unit_of_effort_id "(`Unit`) #{@unit_of_resource}"
@note "A textual description or comment."
@resource_conforms_to """
The primary resource specification or definition of an existing or
potential economic resource.  A resource will have only one, as this
specifies exactly what the resource is.
"""
@resource_conforms_to_id "(`ResourceSpecification`) #{@resource_conforms_to}"
@resource_classified_as """
References a concept in a common taxonomy or other classification scheme
for purposes of categorization or grouping.
"""
@substitutable """
Defines if any resource of that type can be freely substituted for any
other resource of that type when used, consumed, traded, etc.
"""

@desc """
Specifies the resource as part of a recipe, for use in planning from
recipe.
"""
object :recipe_resource do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @unit_of_resource
	field :unit_of_resource, :unit,
		resolve: &Resolv.unit_of_resource/3

	@desc @unit_of_effort
	field :unit_of_effort, :unit,
		resolve: &Resolv.unit_of_effort/3

	@desc @image
	field :image, :base64

	@desc @note
	field :note, :string

	@desc @resource_conforms_to
	field :resource_conforms_to, :resource_specification,
		resolve: &Resolv.resource_conforms_to/3

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @substitutable
	field :substitutable, non_null(:boolean)
end

input_object :recipe_resource_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @unit_of_resource_id
	field :unit_of_resource_id, :id, name: "unit_of_resource"

	@desc @unit_of_effort_id
	field :unit_of_effort_id, :id, name: "unit_of_effort"

	@desc @image
	field :image, :base64

	@desc @note
	field :note, :string

	@desc @resource_conforms_to_id
	field :resource_conforms_to_id, :id, name: "resource_conforms_to"

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @substitutable
	field :substitutable, :boolean
end

input_object :recipe_resource_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @unit_of_resource_id
	field :unit_of_resource_id, :id, name: "unit_of_resource"

	@desc @unit_of_effort_id
	field :unit_of_effort_id, :id, name: "unit_of_effort"

	@desc @image
	field :image, :base64

	@desc @note
	field :note, :string

	@desc @resource_conforms_to_id
	field :resource_conforms_to_id, :id, name: "resource_conforms_to"

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @substitutable
	field :substitutable, :boolean
end

object :recipe_resource_response do
	field :recipe_resource, non_null(:recipe_resource)
end

object :recipe_resource_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:recipe_resource)
end

object :recipe_resource_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:recipe_resource_edge)))
end

object :query_recipe_resource do
	field :recipe_resource, :recipe_resource do
		arg :id, non_null(:id)
		resolve &Resolv.recipe_resource/2
	end

	field :recipe_resources, :recipe_resource_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.recipe_resources/2
	end
end

object :mutation_recipe_resource do
	field :create_recipe_resource, non_null(:recipe_resource_response) do
		arg :recipe_resource, non_null(:recipe_resource_create_params)
		resolve &Resolv.create_recipe_resource/2
	end

	field :update_recipe_resource, non_null(:recipe_resource_response) do
		arg :recipe_resource, non_null(:recipe_resource_update_params)
		resolve &Resolv.update_recipe_resource/2
	end

	field :delete_recipe_resource, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_recipe_resource/2
	end
end
end
