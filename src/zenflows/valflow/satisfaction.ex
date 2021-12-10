defmodule Zenflows.Valflow.Satisfaction do
@moduledoc """
Represents many-to-many relationships between intents and commitments
or events that partially or full satisfy one or more intents.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	EventOrCommitment,
	Intent,
	Measure,
	Validate,
}

@type t() :: %__MODULE__{
	satisfied_by: EventOrCommitment.t(),
	satisfies: Intent.t(),
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	note: String.t() | nil,
}

schema "vf_satisfaction" do
	belongs_to :satisfied_by, EventOrCommitment
	belongs_to :satisfies, Intent
	belongs_to :resource_quantity, Measure
	belongs_to :effort_quantity, Measure
	field :note, :string
end

@reqr ~w[satisfied_by_id satisfies_id]a
@cast @reqr ++ ~w[resource_quantity_id effort_quantity_id note]a

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:satisfied_by)
	|> Changeset.assoc_constraint(:satisfies)
	|> Changeset.assoc_constraint(:resource_quantity)
	|> Changeset.assoc_constraint(:effort_quantity)
end
end
