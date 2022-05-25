defmodule Zenflows.VF.SpatialThing do
@moduledoc """
A physical mappable location.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.Validate

@type t() :: %__MODULE__{
	id: String.t(),
	name: String.t(),
	mappable_address: String.t() | nil,
	lat: float() | nil,
	long: float() | nil,
	alt: float() | nil,
	note: String.t() | nil,
}

@reqr [:name]
@cast @reqr ++ ~w[mappable_address lat long alt note]a

schema "vf_spatial_thing" do
	field :name, :string
	field :mappable_address, :string
	field :lat, :float
	field :long, :float
	field :alt, :float
	field :note, :string
end

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.note(:mappable_address)
end
end
