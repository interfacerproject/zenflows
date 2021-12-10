defmodule Zenflows.Valflow.Process do
@moduledoc """
An activity that changes inputs into outputs.  It could transform or
transport economic resource(s).
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	Plan,
	ProcessSpecification,
	Scenario,
	Validate,
}

@type t() :: %__MODULE__{
	name: String.t(),
	has_beginning: DateTime.t() | nil,
	has_end: DateTime.t() | nil,
	finished: boolean(),
	note: String.t() | nil,
	classified_as: [String.t()],
	based_on: ProcessSpecification.t() | nil,
	planned_within: Plan.t() | nil,
	nested_in: Scenario.t() | nil,
}

schema "vf_process" do
	field :name, :string
	field :has_beginning, :utc_datetime_usec
	field :has_end, :utc_datetime_usec
	field :finished, :boolean, default: false
	field :note, :string
	field :classified_as, {:array, :string}
	belongs_to :based_on, ProcessSpecification
	# belongs_to :in_scope_of
	belongs_to :planned_within, Plan
	belongs_to :nested_in, Scenario
end

@reqr [:name]
@cast @reqr ++ ~w[
	has_beginning has_end
	finished note classified_as
	based_on_id planned_within_id nested_in_id
]a # in_scope_of_id

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.class(:classified_as)
	|> Changeset.assoc_constraint(:based_on)
	#|> Changeset.assoc_constraint(:in_scope_of)
	|> Changeset.assoc_constraint(:planned_within)
	|> Changeset.assoc_constraint(:nested_in)
end
end
