defmodule Zenflows.VF.EconomicResource do
@moduledoc "A resource which is useful to people or the ecosystem."

use Zenflows.DB.Schema

alias Zenflows.VF.{
	Action,
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
	name: String.t(),
	note: String.t() | nil,
	image: String.t() | nil,
	tracking_identifier: String.t() | nil,
	classified_as: [String.t()] | nil,
	conforms_to: ResourceSpecification.t(),
	accounting_quantity: Measure.t() | nil,
	accounting_quantity_has_unit: Unit.t(),
	accounting_quantity_has_numerical_value: float(),
	onhand_quantity: Measure.t() | nil,
	onhand_quantity_has_unit: Unit.t(),
	onhand_quantity_has_numerical_value: float(),
	primary_accountable: Agent.t(),
	custodian: Agent.t(),
	stage: ProcessSpecification.t() | nil,
	state: Action.t() | nil,
	state_id: Action.ID.t() | nil,
	lot: ProductBatch.t() | nil,
	current_location: SpatialThing.t() | nil,
	unit_of_effort: Unit.t() | nil,
	contained_in: EconomicResource.t() | nil,
}

schema "vf_economic_resource" do
	field :name, :string
	field :note, :string
	field :image, :string, virtual: true
	field :tracking_identifier, :string
	field :classified_as, {:array, :string}
	belongs_to :conforms_to, ResourceSpecification
	field :accounting_quantity, :map, virtual: true
	belongs_to :accounting_quantity_has_unit, Unit
	field :accounting_quantity_has_numerical_value, :float
	field :onhand_quantity, :map, virtual: true
	belongs_to :onhand_quantity_has_unit, Unit
	field :onhand_quantity_has_numerical_value, :float
	belongs_to :primary_accountable, Agent
	belongs_to :custodian, Agent
	belongs_to :stage, ProcessSpecification
	field :state_id, Action.ID
	field :state, :map, virtual: true
	belongs_to :current_location, SpatialThing
	belongs_to :lot, ProductBatch
	belongs_to :contained_in, EconomicResource
	belongs_to :unit_of_effort, Unit
end

@reqr ~w[
	name
	conforms_to_id
	primary_accountable_id custodian_id
	accounting_quantity_has_unit_id accounting_quantity_has_numerical_value
	onhand_quantity_has_unit_id onhand_quantity_has_numerical_value
]a
@cast @reqr ++ ~w[
	note image tracking_identifier
	classified_as
	stage_id state_id current_location_id
	lot_id contained_in_id unit_of_effort_id
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
	|> Validate.class(:classified_as)
	|> require_quantity_units_same()
	|> Changeset.assoc_constraint(:conforms_to)
	|> Changeset.assoc_constraint(:accounting_quantity_has_unit)
	|> Changeset.assoc_constraint(:onhand_quantity_has_unit)
	|> Changeset.assoc_constraint(:primary_accountable)
	|> Changeset.assoc_constraint(:custodian)
	|> Changeset.assoc_constraint(:stage)
	|> Changeset.assoc_constraint(:current_location)
	|> Changeset.assoc_constraint(:lot)
	|> Changeset.assoc_constraint(:contained_in)
	|> Changeset.assoc_constraint(:unit_of_effort)
end

# Require that `:accounting_quantity_has_unit_id` and
# `:onhand_quantity_has_unit_id` be the same.
@spec require_quantity_units_same(Changeset.t()) :: Changeset.t()
def require_quantity_units_same(cset) do
	accnt_unit = Changeset.get_field(cset, :accounting_quantity_has_unit_id)
	onhnd_unit = Changeset.get_field(cset, :onhand_quantity_has_unit_id)

	if accnt_unit != onhnd_unit do
		msg = "has_unit: quantity units must be same"
		cset
		|> Changeset.add_error(:accounting_quantity, msg)
		|> Changeset.add_error(:onhand_quantity, msg)
	else
		cset
	end
end
end
