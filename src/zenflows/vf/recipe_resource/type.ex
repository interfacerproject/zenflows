defmodule Zenflows.VF.RecipeResource.Type do
@moduledoc "GraphQL types of RecipeResources."

use Absinthe.Schema.Notation

alias Zenflows.VF.RecipeResource.Resolv

@name """
An informal or formal textual identifier for a recipe resource.  Does not
imply uniqueness.
"""
@image """
The URI to an image relevant to the entity, such as a photo, diagram, etc.
"""
@unit_of_resource """
The unit of inventory used for this resource in the recipe.
"""
@unit_of_effort """
The unit used for use action on this resource or work action in the
recipe.
"""
@note "A textual description or comment."
@resource_conforms_to """
The primary resource specification or definition of an existing or
potential economic resource.  A resource will have only one, as this
specifies exactly what the resource is.
"""
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
	field :image, :uri

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

object :recipe_resource_response do
	field :recipe_resource, non_null(:recipe_resource)
end

input_object :recipe_resource_create_params do
	@desc @name
	field :name, non_null(:string)

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`Unit`) " <> @unit_of_resource
	field :unit_of_resource_id, :id, name: "unit_of_resource"

	@desc "(`Unit`) " <> @unit_of_effort
	field :unit_of_effort_id, :id, name: "unit_of_effort"

	@desc @image
	field :image, :uri

	@desc @note
	field :note, :string

	@desc "(`ResourceSpecification`) " <> @resource_conforms_to
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

	@desc "(`Unit`) " <> @unit_of_resource
	field :unit_of_resource_id, :id, name: "unit_of_resource"

	@desc "(`Unit`) " <> @unit_of_effort
	field :unit_of_effort_id, :id, name: "unit_of_effort"

	@desc @image
	field :image, :uri

	@desc @note
	field :note, :string

	@desc "(`ResourceSpecification`) " <> @resource_conforms_to
	field :resource_conforms_to_id, :id, name: "resource_conforms_to"

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @substitutable
	field :substitutable, :boolean
end

object :query_recipe_resource do
	field :recipe_resource, :recipe_resource do
		arg :id, non_null(:id)
		resolve &Resolv.recipe_resource/2
	end

	#recipeResources(start: ID, limit: Int): [RecipeResource!]
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
