defmodule Zenflows.Valflow.Agreement do
@moduledoc """
A person or group or organization with economic agency.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.Validate

@type t() :: %__MODULE__{
	id: String.t(),
	name: String.t(),
	created: DateTime.t(),
	note: String.t() | nil,
}

@reqr ~w[name created]a
@cast @reqr ++ [:note]

schema "vf_agreement" do
	field :name, :string
	field :created, :utc_datetime_usec
	field :note, :string
end

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
end
end
