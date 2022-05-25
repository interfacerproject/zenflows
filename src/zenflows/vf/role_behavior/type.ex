defmodule Zenflows.VF.RoleBehavior.Type do
@moduledoc "GraphQL types of RoleBehaviors."

use Absinthe.Schema.Notation

alias Zenflows.VF.RoleBehavior.Resolv

@name """
An informal or formal textual identifier for a role behavior.  Does not
imply uniqueness.
"""
@note "A textual description or comment."

@desc """
The general shape or behavior grouping of an agent relationship role.
"""
object :role_behavior do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

object :role_behavior_response do
	field :role_behavior, non_null(:role_behavior)
end

input_object :role_behavior_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

input_object :role_behavior_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string
end

object :query_role_behavior do
	field :role_behavior, :role_behavior do
		arg :id, non_null(:id)
		resolve &Resolv.role_behavior/2
	end
end

object :mutation_role_behavior do
	@desc "Creates a role behavior."
	field :create_role_behavior, non_null(:role_behavior_response) do
		arg :role_behavior, non_null(:role_behavior_create_params)
		resolve &Resolv.create_role_behavior/2
	end

	@desc "Updates a role behavior."
	field :update_role_behavior, non_null(:role_behavior_response) do
		arg :role_behavior, non_null(:role_behavior_update_params)
		resolve &Resolv.update_role_behavior/2
	end

	@desc "Deletes a role behavior."
	field :delete_role_behavior, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_role_behavior/2
	end
end
end
