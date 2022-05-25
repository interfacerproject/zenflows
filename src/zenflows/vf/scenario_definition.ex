defmodule Zenflows.VF.ScenarioDefinition do
@moduledoc """
The type definition of one or more scenarios, such as Yearly Budget.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{
	Duration,
	TimeUnitEnum,
	Validate,
}

@type t() :: %__MODULE__{
	name: String.t(),
	note: String.t() | nil,
	has_duration_unit_type: TimeUnitEnum.t() | nil,
	has_duration_numeric_duration: float() | nil,
	has_duration: Duration.t() | nil,
}

schema "vf_scenario_definition" do
	field :name, :string
	field :note, :string
	field :has_duration, :map, virtual: true
	field :has_duration_unit_type, TimeUnitEnum
	field :has_duration_numeric_duration, :float
end

@reqr [:name]
@cast @reqr ++ ~w[note has_duration]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	Changeset.cast(schema, params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Duration.cast(:has_duration)
end
end
