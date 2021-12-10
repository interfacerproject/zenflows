defmodule Zenflows.Valflow.RoleBehavior do
@moduledoc """
The general shape or behavior grouping of an agent relationship role.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.Validate

@type t() :: %__MODULE__{
	name: String.t(),
	note: String.t() | nil,
}

schema "vf_role_behavior" do
	field :name, :string
	field :note, :string
end

@reqr [:name]
@cast @reqr ++ [:note]

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
