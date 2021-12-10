defmodule Zenflows.Valflow.Unit.Type do
@moduledoc "GraphQL types of Units."

use Absinthe.Schema.Notation

alias Zenflows.Valflow.Unit.Resolv

@label "A human readable label for the unit, can be language specific."
@symbol "A standard display symbol for a unit of measure."

@desc """
Defines a unit of measurement, along with its display symbol.  From OM2
vocabulary.
"""
object :unit do
	field :id, non_null(:id)

	@desc @label
	field :label, non_null(:string)

	@desc @symbol
	field :symbol, non_null(:string)
end

object :unit_response do
	field :unit, :unit
end

input_object :unit_create_params do
	@desc @label
	field :label, non_null(:string)

	@desc @symbol
	field :symbol, non_null(:string)
end

input_object :unit_update_params do
	field :id, non_null(:id)

	@desc @label
	field :label, :string

	@desc @symbol
	field :symbol, :string
end

object :query_unit do
	field :unit, :unit do
		arg :id, non_null(:id)
		resolve &Resolv.unit/2
	end

	#units(start: ID, limit: Int): [Unit!]
end

object :mutation_unit do
	field :create_unit, :unit_response do
		arg :unit, non_null(:unit_create_params)
		resolve &Resolv.create_unit/2
	end

	field :update_unit, :unit_response do
		arg :unit, non_null(:unit_update_params)
		resolve &Resolv.update_unit/2
	end

	field :delete_unit, :boolean do
		arg :id, non_null(:id)
		resolve &Resolv.delete_unit/2
	end
end
end
