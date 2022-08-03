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

defmodule Zenflows.VF.ResourceSpecification.Type do
@moduledoc "GraphQL types of ResourceSpecifications."

use Absinthe.Schema.Notation

alias Zenflows.VF.ResourceSpecification.Resolv

@name """
An informal or formal textual identifier for a type of resource.
Does not imply uniqueness.
"""
@image """
The base64-encoded image binary relevant to the entity, such as a photo,
diagram, etc.
"""
@resource_classified_as """
References a concept in a common taxonomy or other classification scheme
for purposes of categorization or grouping.
"""
@default_unit_of_resource "The default unit used for the resource itself."
@default_unit_of_effort "The default unit used for use or work."
@note "A textual description or comment."

@desc """
Specification of a kind of resource.  Could define a material item,
service, digital item, currency account, etc.  Used instead of a
classification when more information is needed, particularly for recipes.
"""
object :resource_specification do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @image
	field :image, :base64

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @note
	field :note, :string

	@desc @default_unit_of_resource
	field :default_unit_of_resource, :unit,
		resolve: &Resolv.default_unit_of_resource/3

	@desc @default_unit_of_effort
	field :default_unit_of_effort, :unit,
		resolve: &Resolv.default_unit_of_effort/3
end

object :resource_specification_response do
	field :resource_specification, non_null(:resource_specification)
end

input_object :resource_specification_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @image
	field :image, :base64

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @note
	field :note, :string

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @default_unit_of_resource
	field :default_unit_of_resource_id, :id, name: "default_unit_of_resource"

	@desc @default_unit_of_effort
	field :default_unit_of_effort_id, :id, name: "default_unit_of_effort"
end

input_object :resource_specification_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @image
	field :image, :base64

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @note
	field :note, :string

	@desc @default_unit_of_resource
	field :default_unit_of_resource_id, :id, name: "default_unit_of_resource"

	@desc @default_unit_of_effort
	field :default_unit_of_effort_id, :id, name: "default_unit_of_effort"
end

object :query_resource_specification do
	field :resource_specification, :resource_specification do
		arg :id, non_null(:id)
		resolve &Resolv.resource_specification/2
	end

	#resourceSpecifications(start: ID, limit: Int): [ResourceSpecification!]
end

object :mutation_resource_specification do
	field :create_resource_specification, non_null(:resource_specification_response) do
		arg :resource_specification, non_null(:resource_specification_create_params)
		resolve &Resolv.create_resource_specification/2
	end

	field :update_resource_specification, non_null(:resource_specification_response) do
		arg :resource_specification, non_null(:resource_specification_update_params)
		resolve &Resolv.update_resource_specification/2
	end

	field :delete_resource_specification, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_resource_specification/2
	end
end
end
