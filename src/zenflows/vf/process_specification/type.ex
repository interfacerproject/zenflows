defmodule Zenflows.VF.ProcessSpecification.Type do
@moduledoc "GraphQL types of ProcessSpecifications."

use Absinthe.Schema.Notation

alias Zenflows.VF.ProcessSpecification.Resolv

@name """
An informal or formal textual identifier for the process.  Does not
imply uniqueness.
"""
@note "A textual description or comment."

@desc "Specifies the kind of process."
object :process_specification do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

object :process_specification_response do
	field :process_specification, non_null(:process_specification)
end

input_object :process_specification_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

input_object :process_specification_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string
end

object :query_process_specification do
	field :process_specification, :process_specification do
		arg :id, non_null(:id)
		resolve &Resolv.process_specification/2
	end
end

object :mutation_process_specification do
	field :create_process_specification, non_null(:process_specification_response) do
		arg :process_specification, non_null(:process_specification_create_params)
		resolve &Resolv.create_process_specification/2
	end

	field :update_process_specification, non_null(:process_specification_response) do
		arg :process_specification, non_null(:process_specification_update_params)
		resolve &Resolv.update_process_specification/2
	end

	field :delete_process_specification, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_process_specification/2
	end
end
end
