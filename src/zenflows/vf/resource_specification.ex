defmodule Zenflows.VF.ResourceSpecification do
@moduledoc """
Specification of a kind of resource.  Could define a material item,
service, digital item, currency account, etc.  Used instead of a
classification when more information is needed, particularly for recipes.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{Unit, Validate}

@type t() :: %__MODULE__{
	name: String.t(),
	image: String.t() | nil,
	resource_classified_as: [String.t()] | nil,
	note: String.t() | nil,
	default_unit_of_effort: Unit.t() | nil,
	default_unit_of_resource: Unit.t() | nil,
}

schema "vf_resource_specification" do
	field :name, :string
	field :image, :string, virtual: true
	field :resource_classified_as, {:array, :string}
	field :note, :string
	belongs_to :default_unit_of_resource, Unit
	belongs_to :default_unit_of_effort, Unit
end

@reqr [:name]
@cast @reqr ++ ~w[
	resource_classified_as image note
	default_unit_of_effort_id
	default_unit_of_resource_id
]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.uri(:image)
	|> Validate.class(:resource_classified_as)
	|> Changeset.assoc_constraint(:default_unit_of_resource)
	|> Changeset.assoc_constraint(:default_unit_of_effort)
end
end
