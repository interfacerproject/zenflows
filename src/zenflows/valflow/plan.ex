defmodule Zenflows.Valflow.Plan do
@moduledoc """
A logical collection of processes that constitute a body of planned work
with defined deliverable(s).
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{Scenario, Validate}

@type t() :: %__MODULE__{
	name: String.t(),
	created: DateTime.t() | nil,
	due: DateTime.t() | nil,
	note: String.t() | nil,
	refinement_of: Scenario.t() | nil,
}

schema "vf_plan" do
	field :name, :string
	field :created, :utc_datetime_usec
	field :due, :utc_datetime_usec
	field :note, :string
	belongs_to :refinement_of, Scenario
end

@reqr [:name]
@cast @reqr ++ ~w[created due note refinement_of_id]a

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:refinement_of)
end
end
