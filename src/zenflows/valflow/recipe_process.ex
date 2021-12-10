defmodule Zenflows.Valflow.RecipeProcess do
@moduledoc """
Specifies a process in a recipe for use in planning from recipe.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	Duration,
	ProcessSpecification,
	Validate,
}

@type t() :: %__MODULE__{
	name: String.t(),
	has_duration: Duration.t() | nil,
	process_classified_as: [String.t()] | nil,
	process_conforms_to: ProcessSpecification.t() | nil,
	note: String.t() | nil,
}

schema "vf_recipe_process" do
	field :name, :string
	belongs_to :has_duration, Duration, on_replace: :delete_if_exists
	field :process_classified_as, {:array, :string}
	belongs_to :process_conforms_to, ProcessSpecification
	field :note, :string
end

@reqr [:name]
@cast @reqr ++ ~w[
	process_classified_as
	process_conforms_to_id note
]a

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.class(:process_classified_as)
	|> Changeset.cast_assoc(:has_duration, with: &Duration.chset/2)
	|> Changeset.assoc_constraint(:has_duration)
	|> Changeset.assoc_constraint(:process_conforms_to)
end
end
