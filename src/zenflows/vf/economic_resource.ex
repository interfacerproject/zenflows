# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.EconomicResource do
@moduledoc "A resource which is useful to people or the ecosystem."

use Zenflows.DB.Schema

alias Zenflows.File
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
	images: [File.t()],
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
	okhv: String.t() | nil,
	repo: String.t() | nil,
	version: String.t() | nil,
	licensor: String.t() | nil,
	license: String.t() | nil,
	metadata: map() | nil,
}

schema "vf_economic_resource" do
	field :name, :string
	field :note, :string
	has_many :images, File
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
	field :okhv, :string
	field :repo, :string
	field :version, :string
	field :licensor, :string
	field :license, :string
	field :metadata, :map
	timestamps()
end

@reqr ~w[
	name
	conforms_to_id
	primary_accountable_id custodian_id
	accounting_quantity_has_unit_id accounting_quantity_has_numerical_value
	onhand_quantity_has_unit_id onhand_quantity_has_numerical_value
]a
@cast @reqr ++ ~w[
	note tracking_identifier
	classified_as
	stage_id state_id current_location_id
	lot_id contained_in_id unit_of_effort_id
	okhv repo version licensor license metadata
]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.class(:classified_as)
	|> Validate.name(:okhv)
	|> Validate.uri(:repo)
	|> Validate.name(:version)
	|> Validate.name(:licensor)
	|> Validate.name(:license)
	|> require_quantity_units_same()
	|> Changeset.cast_assoc(:images, with: &File.chgset/2)
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
