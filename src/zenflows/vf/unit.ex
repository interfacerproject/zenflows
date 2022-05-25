defmodule Zenflows.VF.Unit do
@moduledoc """
Defines a unit of measurement, along with its display symbol.
From OM2 vocabulary.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.Validate

@type t() :: %__MODULE__{
	id: String.t(),
	label: String.t(),
	symbol: String.t(),
}

schema "vf_unit" do
	field :label, :string
	field :symbol, :string
end

@reqr ~w[label symbol]a
@cast @reqr

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:label)
	|> Validate.name(:symbol)
end
end
