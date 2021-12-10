defmodule Zenflows.Valflow.Action do
@moduledoc """
An action verb defining the kind of event, commitment, or intent.
"""

use Ecto.Schema

alias Ecto.Enum

@type t() :: %__MODULE__{
	id: atom(),
	label: atom(),
	resource_effect: atom(),
	onhand_effect: atom(),
	input_output: atom(),
	pairs_with: atom(),
}

@actions ~w[
	produce use consume cite work pickup dropoff
	accept modify pack unpack
	transfer_all_rights transfer_custody transfer
	move raise lower
]a
@effects ~w[increment decrement no_effect decrement_increment]a
@input_outputs ~w[input output not_applicable]a
@pairs_withs [:not_applicable | @actions]

@primary_key {:id, Enum, values: @actions}
embedded_schema do
	field :label, Enum, values: @actions
	field :resource_effect, Enum, values: @effects
	field :onhand_effect, Enum, values: @effects
	field :input_output, Enum, values: @input_outputs
	field :pairs_with, Enum, values: @pairs_withs
end
end
