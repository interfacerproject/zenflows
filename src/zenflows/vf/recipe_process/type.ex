defmodule Zenflows.VF.RecipeProcess.Type do
@moduledoc "GraphQL types of RecipeProcesses."

use Absinthe.Schema.Notation

alias Zenflows.VF.RecipeProcess.Resolv

@name """
An informal or formal textual identifier for a recipe process.  Does not
imply uniqueness.
"""
@has_duration """
The planned calendar duration of the process as defined for the recipe
batch.
"""
@process_classified_as """
References a concept in a common taxonomy or other classification scheme
for purposes of categorization.
"""
@process_conforms_to """
The standard specification or definition of a process.
"""
@note "A textual description or comment."

@desc "Specifies a process in a recipe for use in planning from recipe."
object :recipe_process do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @has_duration
	field :has_duration, :duration, resolve: &Resolv.has_duration/3

	@desc @process_classified_as
	field :process_classified_as, list_of(non_null(:uri))

	@desc @process_conforms_to
	field :process_conforms_to, non_null(:process_specification),
		resolve: &Resolv.process_conforms_to/3

	@desc @note
	field :note, :string
end

object :recipe_process_response do
	field :recipe_process, non_null(:recipe_process)
end

input_object :recipe_process_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @has_duration
	field :has_duration, :iduration

	@desc @process_classified_as
	field :process_classified_as, list_of(non_null(:uri))

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`ProcessSpecification`) " <> @process_conforms_to
	field :process_conforms_to_id, non_null(:id), name: "process_conforms_to"

	@desc @note
	field :note, :string
end

input_object :recipe_process_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @has_duration
	field :has_duration, :iduration

	@desc @process_classified_as
	field :process_classified_as, list_of(non_null(:uri))

	@desc "(`ProcessSpecification`) " <> @process_conforms_to
	field :process_conforms_to_id, :id, name: "process_conforms_to"

	@desc @note
	field :note, :string
end

object :query_recipe_process do
	field :recipe_process, :recipe_process do
		arg :id, non_null(:id)
		resolve &Resolv.recipe_process/2
	end

	#recipeProcesses(start: ID, limit: Int): [RecipeProcess!]
end

object :mutation_recipe_process do
	field :create_recipe_process, non_null(:recipe_process_response) do
		arg :recipe_process, non_null(:recipe_process_create_params)
		resolve &Resolv.create_recipe_process/2
	end

	field :update_recipe_process, non_null(:recipe_process_response) do
		arg :recipe_process, non_null(:recipe_process_update_params)
		resolve &Resolv.update_recipe_process/2
	end

	field :delete_recipe_process, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_recipe_process/2
	end
end
end
