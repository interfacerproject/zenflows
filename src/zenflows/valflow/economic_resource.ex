defmodule Zenflows.Valflow.EconomicResource do
@moduledoc """
A resource which is useful to people or the ecosystem.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	ActionEnum,
	Agent,
	EconomicResource,
	Measure,
	ProcessSpecification,
	ProductBatch,
	ResourceSpecification,
	SpatialThing,
	Unit,
	Validate,
}

@type t() :: %__MODULE__{
	name: String.t() | nil,
	primary_accountable: Agent.t() | nil,
	classified_as: list(String.t()) | nil,
	conforms_to: ResourceSpecification.t(),
	tracking_identifier: String.t() | nil,
	lot: ProductBatch.t() | nil,
	image: String.t() | nil,
	accounting_quantity: Measure.t() | nil,
	onhand_quantity: Measure.t() | nil,
	current_location: SpatialThing.t() | nil,
	note: String.t() | nil,
	unit_of_effort: Unit.t() | nil,
	stage: ProcessSpecification.t() | nil,
	state: ActionEnum.t() | nil,
	contained_in: EconomicResource.t() | nil,
}

schema "vf_economic_resource" do
	field :name, :string
	belongs_to :primary_accountable, Agent
	field :classified_as, {:array, :string}
	belongs_to :conforms_to, ResourceSpecification
	field :tracking_identifier, :string
	belongs_to :lot, ProductBatch
	field :image, :string, virtual: true
	belongs_to :accounting_quantity, Measure
	belongs_to :onhand_quantity, Measure
	belongs_to :current_location, SpatialThing
	field :note, :string
	belongs_to :unit_of_effort, Unit
	belongs_to :stage, ProcessSpecification
	field :state, ActionEnum
	belongs_to :contained_in, EconomicResource
end

@reqr [:conforms_to_id]
@cast @reqr ++ ~w[
	primary_accountable_id name classified_as tracking_identifier
	lot_id accounting_quantity_id onhand_quantity_id
	current_location_id image note unit_of_effort_id stage_id
	state contained_in_id
]a

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.uri(:image)
	|> Validate.class(:primary_accountable)
	|> Validate.class(:classified_as)
	|> Changeset.assoc_constraint(:conforms_to)
	|> Changeset.assoc_constraint(:lot)
	|> Changeset.assoc_constraint(:accounting_quantity)
	|> Changeset.assoc_constraint(:onhand_quantity)
	|> Changeset.assoc_constraint(:current_location)
	|> Changeset.assoc_constraint(:unit_of_effort)
	|> Changeset.assoc_constraint(:stage)
	|> Changeset.assoc_constraint(:contained_in)
end
end
