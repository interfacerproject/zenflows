defmodule Zenflows.Valflow.Duration do
@moduledoc """
Represents an interval between two DateTime values.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.TimeUnitEnum

@type t() :: %__MODULE__{
	unit_type: TimeUnitEnum.t(),
	numeric_duration: float(),
}

schema "vf_duration" do
	field :unit_type, TimeUnitEnum
	field :numeric_duration, :float
end

@reqr ~w[unit_type numeric_duration]a
@cast @reqr

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.validate_number(:numeric_duration, greater_than_or_equal_to: 0)
end
end
