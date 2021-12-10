defmodule Zenflows.Valflow.Fulfillment do
@moduledoc """
Represents many-to-many relationships between commitments and economic
events that fully or partially satisfy one or more commitments.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	Commitment,
	EconomicEvent,
	Measure,
	Validate,
}

@type t() :: %__MODULE__{
	fulfilled_by: EconomicEvent.t(),
	fulfills: Commitment.t(),
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	note: String.t() | nil,
}

schema "vf_fulfillment" do
	belongs_to :fulfilled_by, EconomicEvent
	belongs_to :fulfills, Commitment
	belongs_to :resource_quantity, Measure
	belongs_to :effort_quantity, Measure
	field :note, :string
end

@reqr ~w[fulfilled_by_id fulfills_id]a
@cast @reqr ++ ~w[resource_quantity_id effort_quantity_id note]a

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:fulfilled_by)
	|> Changeset.assoc_constraint(:fulfills)
	|> Changeset.assoc_constraint(:resource_quantity)
	|> Changeset.assoc_constraint(:effort_quantity)
end
end
