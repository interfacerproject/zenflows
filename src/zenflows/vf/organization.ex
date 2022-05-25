defmodule Zenflows.VF.Organization do
@moduledoc "A formal or informal group, or legal organization."

use Zenflows.DB.Schema

alias Zenflows.VF.{SpatialThing, Validate}

@type t() :: %__MODULE__{
	type: :org,
	name: String.t(),
	image: String.t() | nil,
	note: String.t() | nil,
	primary_location: SpatialThing.t() | nil,
	classified_as: [String.t()] | nil,
}

schema "vf_agent" do
	field :type, Ecto.Enum, values: [:org], default: :org
	field :name, :string
	field :image, :string, virtual: true
	field :note, :string
	belongs_to :primary_location, SpatialThing
	field :classified_as, {:array, :string}
end

@reqr [:name]
@cast @reqr ++ ~w[classified_as image note primary_location_id]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.uri(:image)
	|> Validate.class(:classified_as)
	|> Changeset.assoc_constraint(:primary_location)
end
end
