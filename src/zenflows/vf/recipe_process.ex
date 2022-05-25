defmodule Zenflows.VF.RecipeProcess do
@moduledoc """
Specifies a process in a recipe for use in planning from recipe.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{
	Duration,
	ProcessSpecification,
	TimeUnitEnum,
	Validate,
}

@type t() :: %__MODULE__{
	name: String.t(),
	note: String.t() | nil,
	process_conforms_to: ProcessSpecification.t() | nil,
	process_classified_as: [String.t()] | nil,
	has_duration: Duration.t() | nil,
	has_duration_unit_type: TimeUnitEnum.t() | nil,
	has_duration_numeric_duration: float() | nil,
}

schema "vf_recipe_process" do
	field :name, :string
	field :note, :string
	belongs_to :process_conforms_to, ProcessSpecification
	field :process_classified_as, {:array, :string}
	field :has_duration, :map, virtual: true
	field :has_duration_unit_type, TimeUnitEnum
	field :has_duration_numeric_duration, :float
end

@reqr ~w[name process_conforms_to_id]a
@cast @reqr ++ ~w[process_classified_as note has_duration]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.class(:process_classified_as)
	|> Duration.cast(:has_duration)
	|> Changeset.assoc_constraint(:process_conforms_to)
end
end
