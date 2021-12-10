defmodule Zenflows.Valflow.Measure do
@moduledoc """
Semantic meaning for measurements: binds a quantity to its measurement
unit.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.Unit

@type t() :: %__MODULE__{
	has_unit: Unit.t(),
	has_numerical_value: float(),
}

schema "vf_measure" do
	belongs_to :has_unit, Unit
	field :has_numerical_value, :float
end

@reqr [:has_unit_id]
@cast @reqr ++ [:has_numerical_value]

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.assoc_constraint(:has_unit)
end
end
