defmodule Zenflows.VF.Agreement do
@moduledoc "Any type of agreement among economic agents."

use Zenflows.DB.Schema

alias Zenflows.VF.Validate

@type t() :: %__MODULE__{
	id: String.t(),
	name: String.t(),
	note: String.t() | nil,
	created: DateTime.t(),
}

@reqr ~w[name created]a
@cast @reqr ++ [:note]

schema "vf_agreement" do
	field :name, :string
	field :note, :string
	field :created, :utc_datetime_usec
end

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
end
end
