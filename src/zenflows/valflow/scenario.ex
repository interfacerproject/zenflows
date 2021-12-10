defmodule Zenflows.Valflow.Scenario do
@moduledoc """
An estimated or analytical logical collection of higher level processes
used for budgeting, analysis, plan refinement, etc.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	Scenario,
	ScenarioDefinition,
	Validate,
}

@type t() :: %__MODULE__{
	name: String.t(),
	has_beginning: DateTime.t() | nil,
	has_end: DateTime.t() | nil,
	defined_as: ScenarioDefinition.t() | nil,
	refinement_of: Scenario.t() | nil,
	note: String.t() | nil,
}

schema "vf_scenario" do
	field :name, :string
	field :has_beginning, :utc_datetime_usec
	field :has_end, :utc_datetime_usec
	# field :in_scope_of
	belongs_to :defined_as, ScenarioDefinition
	belongs_to :refinement_of, Scenario
	field :note, :string
end

@reqr [:name]
@cast @reqr ++ ~w[
	has_beginning has_end
	defined_as_id refinement_of_id
	note
]a

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:defined_as)
	|> Changeset.assoc_constraint(:refinement_of)
end
end
