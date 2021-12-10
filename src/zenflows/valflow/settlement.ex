defmodule Zenflows.Valflow.Settlement do
@moduledoc """
Represents many-to-many relationships between claim and economic events
that fully or partially settle one or more claims.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	Claim,
	EconomicEvent,
	Measure,
	Validate,
}

@type t() :: %__MODULE__{
	settled_by: EconomicEvent.t(),
	settles: Claim.t(),
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	note: String.t() | nil,
}

schema "vf_settlement" do
	belongs_to :settled_by, EconomicEvent
	belongs_to :settles, Claim
	belongs_to :resource_quantity, Measure
	belongs_to :effort_quantity, Measure
	field :note, :string
end

@reqr ~w[settled_by_id settles_id]a
@cast @reqr ++ ~w[resource_quantity_id effort_quantity_id note]a

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:settled_by)
	|> Changeset.assoc_constraint(:settles)
	|> Changeset.assoc_constraint(:resource_quantity)
	|> Changeset.assoc_constraint(:effort_quantity)
end
end
