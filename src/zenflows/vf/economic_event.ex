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

defmodule Zenflows.VF.EconomicEvent do
@moduledoc """
An observed economic flow, as opposed to a flow planned to happen in
the future.  This could reflect a change in the quantity of an economic
resource.  It is also defined by its behavior in relation to the economic
resource.
"""
use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Action,
	Agent,
	Agreement,
	EconomicEvent,
	EconomicResource,
	Measure,
	Process,
	ResourceSpecification,
	SpatialThing,
	Unit,
}

@type t() :: %__MODULE__{
	action: Action.t(),
	input_of: Process.t() | nil,
	output_of: Process.t() | nil,
	provider: Agent.t(),
	receiver: Agent.t(),
	resource_inventoried_as: EconomicResource.t() | nil,
	to_resource_inventoried_as: EconomicResource.t() | nil,
	resource_classified_as: [String.t()] | nil,
	resource_conforms_to: ResourceSpecification.t() | nil,
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	has_beginning: DateTime.t() | nil,
	has_end: DateTime.t() | nil,
	has_point_in_time: DateTime.t() | nil,
	note: String.t() | nil,
	to_location: SpatialThing.t() | nil,
	at_location: SpatialThing.t() | nil,
	realization_of: Agreement.t() | nil,
	# in_scope_of:
	agreed_in: String.t() | nil,
	triggered_by: EconomicEvent.t() | nil,
	previous_event: nil | EconomicEvent.t(),
	resource_metadata: nil | map(),
}

@derive {Jason.Encoder, only: ~w[
	id
	action_id
	resource_classified_as
	resource_quantity_has_numerical_value
	effort_quantity_has_numerical_value
	has_beginning has_end has_point_in_time
	note agreed_in
	input_of_id output_of_id
	provider_id receiver_id
	resource_inventoried_as_id to_resource_inventoried_as_id
	resource_conforms_to_id
	resource_quantity_has_unit_id effort_quantity_has_unit_id
	to_location_id at_location_id
	realization_of_id
	triggered_by_id
	previous_event_id
	resource_metadata
]a}
schema "vf_economic_event" do
	field :action_id, Action.ID
	field :action, :map, virtual: true
	belongs_to :input_of, Process
	belongs_to :output_of, Process
	belongs_to :provider, Agent
	belongs_to :receiver, Agent
	belongs_to :resource_inventoried_as, EconomicResource
	belongs_to :to_resource_inventoried_as, EconomicResource
	field :resource_classified_as, {:array, :string}
	belongs_to :resource_conforms_to, ResourceSpecification
	field :resource_quantity, :map, virtual: true
	belongs_to :resource_quantity_has_unit, Unit
	field :resource_quantity_has_numerical_value, :decimal
	field :effort_quantity, :map, virtual: true
	belongs_to :effort_quantity_has_unit, Unit
	field :effort_quantity_has_numerical_value, :decimal
	field :has_beginning, :utc_datetime_usec
	field :has_end, :utc_datetime_usec
	field :has_point_in_time, :utc_datetime_usec
	field :note, :string
	belongs_to :to_location, SpatialThing
	belongs_to :at_location, SpatialThing
	belongs_to :realization_of, Agreement
	# field :in_scope_of
	field :agreed_in, :string
	belongs_to :triggered_by, EconomicEvent
	belongs_to :previous_event, EconomicEvent
	field :resource_metadata, :map
	timestamps()
end

@insert_reqr ~w[action_id provider_id receiver_id]a
@insert_cast @insert_reqr ++ ~w[
	has_beginning has_end has_point_in_time note at_location_id
	realization_of_id agreed_in triggered_by_id previous_event_id
]a

# insert changeset
@doc false
@spec changeset(Schema.params()) :: Changeset.t()
def changeset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @insert_cast)
	|> Changeset.validate_required(@insert_reqr)
	|> Validate.exist_or([:has_point_in_time, :has_beginning, :has_end])
	|> Validate.exist_nand([:has_point_in_time, :has_beginning])
	|> Validate.exist_nand([:has_point_in_time, :has_end])
	|> do_changeset()
	|> Validate.uri(:agreed_in)
	|> Validate.note(:note)
	|> Validate.class(:resource_classified_as)
	|> Changeset.assoc_constraint(:input_of)
	|> Changeset.assoc_constraint(:output_of)
	|> Changeset.assoc_constraint(:provider)
	|> Changeset.assoc_constraint(:receiver)
	|> Changeset.assoc_constraint(:resource_inventoried_as)
	|> Changeset.assoc_constraint(:to_resource_inventoried_as)
	|> Changeset.assoc_constraint(:resource_conforms_to)
	|> Changeset.assoc_constraint(:to_location)
	|> Changeset.assoc_constraint(:at_location)
	|> Changeset.assoc_constraint(:realization_of)
	|> Changeset.assoc_constraint(:triggered_by)
	|> Changeset.assoc_constraint(:previous_event)
end

@spec do_changeset(Changeset.t()) :: Changeset.t()
defp do_changeset(%{valid?: false} = cset), do: cset
defp do_changeset(%{changes: %{action_id: "raise"}} = cset) do
	cset
	|> Changeset.cast(cset.params, ~w[
		resource_conforms_to_id resource_inventoried_as_id
		resource_classified_as resource_quantity to_location_id
		resource_metadata
	]a)
	|> Changeset.validate_required([:resource_quantity])
	|> Measure.cast(:resource_quantity)
	|> Validate.value_eq([:provider_id, :receiver_id])
	|> Validate.exist_xor([:resource_conforms_to_id, :resource_inventoried_as_id])
end
defp do_changeset(%{changes: %{action_id: "produce"}} = cset) do
	cset
	|> Changeset.cast(cset.params, ~w[
		output_of_id resource_conforms_to_id resource_inventoried_as_id
		resource_classified_as resource_quantity to_location_id
		resource_metadata
	]a)
	|> Changeset.validate_required(~w[output_of_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
	|> Validate.value_eq([:provider_id, :receiver_id])
	|> Validate.exist_xor([:resource_conforms_to_id, :resource_inventoried_as_id])
end
defp do_changeset(%{changes: %{action_id: "lower"}} = cset) do
	cset
	|> Changeset.cast(cset.params, ~w[resource_inventoried_as_id resource_quantity]a)
	|> Changeset.validate_required(~w[resource_inventoried_as_id resource_quantity]a)
	|> Validate.value_eq([:provider_id, :receiver_id])
	|> Measure.cast(:resource_quantity)
end
defp do_changeset(%{changes: %{action_id: "consume"}} = cset) do
	cset
	|> Changeset.cast(cset.params,
		~w[input_of_id resource_inventoried_as_id resource_quantity]a)
	|> Changeset.validate_required(
		~w[input_of_id resource_inventoried_as_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
	|> Validate.value_eq([:provider_id, :receiver_id])
end
defp do_changeset(%{changes: %{action_id: "use"}} = cset) do
	cset
	|> Changeset.cast(cset.params, ~w[
		input_of_id effort_quantity
		resource_inventoried_as_id resource_conforms_to_id
		resource_quantity
	]a)
	|> Changeset.validate_required(~w[input_of_id effort_quantity]a)
	|> Measure.cast(:effort_quantity)
	|> Measure.cast(:resource_quantity)
	|> Validate.exist_xor([:resource_inventoried_as_id, :resource_conforms_to_id])
end
defp do_changeset(%{changes: %{action_id: "work"}} = cset) do
	cset
	|> Changeset.cast(cset.params,
		~w[input_of_id effort_quantity resource_conforms_to_id]a)
	|> Changeset.validate_required(
		~w[input_of_id effort_quantity resource_conforms_to_id]a)
	|> Measure.cast(:effort_quantity)
end
defp do_changeset(%{changes: %{action_id: "cite"}} = cset) do
	cset
	|> Changeset.cast(cset.params, ~w[
		input_of_id resource_quantity
		resource_inventoried_as_id resource_conforms_to_id
	]a)
	|> Changeset.validate_required(~w[input_of_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
	|> Validate.exist_xor([:resource_inventoried_as_id, :resource_conforms_to_id])
end
defp do_changeset(%{changes: %{action_id: "deliverService"}} = cset) do
	cset
	|> Changeset.cast(cset.params,
		~w[input_of_id output_of_id resource_conforms_to_id resource_quantity]a)
	|> Changeset.validate_required(~w[resource_conforms_to_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
	|> Validate.value_ne([:input_of_id, :output_of_id])
end
defp do_changeset(%{changes: %{action_id: "pickup"}} = cset) do
	cset
	|> Changeset.cast(cset.params,
		~w[input_of_id resource_quantity resource_inventoried_as_id]a)
	|> Changeset.validate_required(
		~w[input_of_id resource_quantity resource_inventoried_as_id]a)
	|> Measure.cast(:resource_quantity)
	|> Validate.value_eq([:provider_id, :receiver_id])
end
defp do_changeset(%{changes: %{action_id: "dropoff"}} = cset) do
	cset
	|> Changeset.cast(cset.params,
		~w[output_of_id resource_quantity resource_inventoried_as_id to_location_id]a)
	|> Changeset.validate_required(
		~w[output_of_id resource_quantity resource_inventoried_as_id]a)
	|> Measure.cast(:resource_quantity)
	|> Validate.value_eq([:provider_id, :receiver_id])
end
defp do_changeset(%{changes: %{action_id: "accept"}} = cset) do
	cset
	|> Changeset.cast(cset.params,
		~w[input_of_id resource_quantity resource_inventoried_as_id]a)
	|> Changeset.validate_required(
		~w[input_of_id resource_quantity resource_inventoried_as_id]a)
	|> Measure.cast(:resource_quantity)
	|> Validate.value_eq([:provider_id, :receiver_id])
end
defp do_changeset(%{changes: %{action_id: "modify"}} = cset) do
	cset
	|> Changeset.cast(cset.params,
		~w[output_of_id resource_quantity resource_inventoried_as_id resource_metadata]a)
	|> Changeset.validate_required(
		~w[output_of_id resource_quantity resource_inventoried_as_id]a)
	|> Measure.cast(:resource_quantity)
	|> Validate.value_eq([:provider_id, :receiver_id])
end
defp do_changeset(%{changes: %{action_id: "combine"}} = cset) do
	cset
	|> Changeset.cast(cset.params, ~w[]a)
	|> Changeset.validate_required(~w[]a)
end
defp do_changeset(%{changes: %{action_id: "separate"}} = cset) do
	cset
	|> Changeset.cast(cset.params, ~w[]a)
	|> Changeset.validate_required(~w[]a)
end
defp do_changeset(%{changes: %{action_id: "transferAllRights"}} = cset) do
	cset
	|> Changeset.cast(cset.params, ~w[
		resource_inventoried_as_id to_resource_inventoried_as_id
		resource_quantity resource_classified_as
	]a)
	|> Changeset.validate_required(~w[resource_inventoried_as_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
end
defp do_changeset(%{changes: %{action_id: id}} = cset)
		when id in ~w[transferCustody transfer] do
	cset
	|> Changeset.cast(cset.params, ~w[
		resource_inventoried_as_id to_resource_inventoried_as_id resource_quantity
		to_location_id resource_classified_as
	]a)
	|> Changeset.validate_required(~w[resource_inventoried_as_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
end
defp do_changeset(%{changes: %{action_id: "move"}} = cset) do
	cset
	|> Changeset.cast(cset.params, ~w[
		resource_inventoried_as_id to_resource_inventoried_as_id resource_quantity
		to_location_id resource_classified_as
	]a)
	|> Changeset.validate_required(~w[resource_inventoried_as_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
	|> Validate.value_eq([:provider_id, :receiver_id])
end

@update_cast ~w[note agreed_in realization_of_id triggered_by_id]a

# update changeset
@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema, params) do
	schema
	|> Changeset.cast(params, @update_cast)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:realization_of)
	|> Changeset.assoc_constraint(:triggered_by)
end
end
