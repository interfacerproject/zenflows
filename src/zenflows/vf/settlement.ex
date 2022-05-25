defmodule Zenflows.VF.Settlement do
@moduledoc """
Represents many-to-many relationships between claim and economic events
that fully or partially settle one or more claims.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{
	Claim,
	EconomicEvent,
	Measure,
	Unit,
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
	field :resource_quantity, :map, virtual: true
	belongs_to :resource_quantity_has_unit, Unit
	field :resource_quantity_has_numerical_value, :float
	field :effort_quantity, :map, virtual: true
	belongs_to :effort_quantity_has_unit, Unit
	field :effort_quantity_has_numerical_value, :float
	field :note, :string
end

@reqr ~w[settled_by_id settles_id]a
@cast @reqr ++ ~w[resource_quantity effort_quantity note]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Measure.cast(:resource_quantity)
	|> Measure.cast(:effort_quantity)
	|> Changeset.assoc_constraint(:settled_by)
	|> Changeset.assoc_constraint(:settles)
end
end
