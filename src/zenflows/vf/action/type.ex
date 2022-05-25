defmodule Zenflows.VF.Action.Type do
@moduledoc "GraphQL types of Actions."

use Absinthe.Schema.Notation

@desc """
An action verb defining the kind of event, commitment, or intent.
It is recommended that the lowercase action verb should be used as the
record ID in order that references to `Action`s elsewhere in the system
are easily readable.
"""
object :action do
	field :id, non_null(:string)

	@desc "A unique verb which defines the action."
	field :label, non_null(:string)

	@desc """
	The accounting effect of an economic event on a resource,
	increment, decrement, no effect, or decrement resource and
	increment "to" resource.
	"""
	field :resource_effect, non_null(:string) # "increment", "decrement", "noEffect", "decrementIncrement"

	@desc """
	The onhand effect of an economic event on a resource, increment,
	decrement, no effect, or decrement resource and increment "to"
	resource.
	"""
	field :onhand_effect, non_null(:string) # "increment", "decrement", "noEffect", "decrementIncrement"

	@desc "Denotes if a process input or output, or not related to a process."
	field :input_output, :string # "input", "output", "notApplicable"

	@desc """
	The action that should be included on the other direction of
	the process, for example accept with modify.
	"""
	field :pairs_with, :string # "notApplicable", (any of the action labels)
end
end
