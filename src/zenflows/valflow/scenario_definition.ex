defmodule Zenflows.Valflow.ScenarioDefinition do
@moduledoc """
The type definition of one or more scenarios, such as Yearly Budget.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{Duration, Validate}

@type t() :: %__MODULE__{
	name: String.t(),
	has_duration: Duration.t() | nil,
	note: String.t() | nil,
}

schema "vf_scenario_definition" do
	field :name, :string
	belongs_to :has_duration, Duration
	field :note, :string
end

@reqr [:name]
@cast @reqr ++ ~w[note has_duration_id]a

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:has_duration)
end
end
