# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
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

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Action,
	Agent,
	EconomicEvent,
	EconomicResource,
	Measure,
	ProcessSpecification,
	ProductBatch,
	ResourceSpecification,
	SpatialThing,
	Unit,
}

@type t() :: %__MODULE__{
	name: String.t(),
	note: String.t() | nil,
	images: [map()],
	tracking_identifier: String.t() | nil,
	classified_as: [String.t()] | nil,
	conforms_to: ResourceSpecification.t(),
	accounting_quantity: Measure.t() | nil,
	accounting_quantity_has_unit: Unit.t(),
	accounting_quantity_has_numerical_value: Decimal.t(),
	onhand_quantity: Measure.t() | nil,
	onhand_quantity_has_unit: Unit.t(),
	onhand_quantity_has_numerical_value: Decimal.t(),
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
	previous_event: nil | EconomicEvent.t(),
}

@derive {Jason.Encoder, only: ~w[
	id
	name note tracking_identifier classified_as state_id okhv
	repo version licensor license metadata
	accounting_quantity_has_numerical_value
	accounting_quantity_has_unit_id
	onhand_quantity_has_numerical_value
	onhand_quantity_has_unit_id
	conforms_to_id primary_accountable_id custodian_id
	stage_id current_location_id lot_id contained_in_id
	unit_of_effort_id previous_event_id
]a}

schema "vf_economic_resource" do
	field :name, :string
	field :note, :string
	field :images, {:array, :map}, virtual: true
	field :tracking_identifier, :string
	field :classified_as, {:array, :string}
	belongs_to :conforms_to, ResourceSpecification
	field :accounting_quantity, :map, virtual: true
	belongs_to :accounting_quantity_has_unit, Unit
	field :accounting_quantity_has_numerical_value, :decimal
	field :onhand_quantity, :map, virtual: true
	belongs_to :onhand_quantity_has_unit, Unit
	field :onhand_quantity_has_numerical_value, :decimal
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
	belongs_to :previous_event, EconomicEvent
	timestamps()
end

@reqr ~w[
	name
	conforms_to_id
	primary_accountable_id custodian_id
	accounting_quantity_has_unit_id accounting_quantity_has_numerical_value
	onhand_quantity_has_unit_id onhand_quantity_has_numerical_value
	previous_event_id
]a
@cast @reqr ++ ~w[
	note tracking_identifier
	classified_as
	stage_id state_id current_location_id
	lot_id contained_in_id unit_of_effort_id
	okhv repo version licensor license metadata
	images
]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
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
	|> Validate.value_eq([:accounting_quantity_has_unit_id, :onhand_quantity_has_unit_id])
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
	|> Changeset.assoc_constraint(:previous_event)
end

# This is only used for `Zenflows.VF.EconomicResource.Domain.trace_dpp/1`.
defimpl Jason.Encoder, for: __MODULE__ do
	def encode(res, opts) do
		Jason.Encode.map(%{
			"id" => res.id,
			"name" => res.name,
			"note" => res.note,
			"trackingIdentifier" => res.tracking_identifier,
			"classifiedAs" => res.classified_as,
			"state" => %{"id" => res.state_id},
			"okhv" => res.okhv,
			"repo" => res.repo,
			"version" => res.version,
			"licensor" => res.licensor,
			"license" => res.license,
			"metadata" => res.metadata,
			"accountingQuantity" => %{
				"hasNumericalValue" => res.accounting_quantity_has_numerical_value,
				"hasUnit" => %{"id" => res.accounting_quantity_has_unit_id},
			},
			"onhandQuantityHas" => %{
				"numericalValue" => res.onhand_quantity_has_numerical_value,
				"hasUnit" => %{"id" => res.onhand_quantity_has_unit_id},
			},
			"conformsTo" => %{"id" => res.conforms_to_id},
			"primaryAccountable" => %{"id" => res.primary_accountable_id},
			"custodian" => %{"id" => res.custodian_id},
			"stage" => %{"id" => res.stage_id},
			"currentLocation" => %{"id" => res.current_location_id},
			"lot" => %{"id" => res.lot_id},
			"containedIn" => %{"id" => res.contained_in_id},
			"unitOfEffort" => %{"id" => res.unit_of_effort_id},
			"previousEvent" => %{"id" => res.previous_event_id},
		}, opts)
	end
end
end
