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

defmodule Zenflows.VF.EconomicEvent do
@moduledoc """
An observed economic flow, as opposed to a flow planned to happen in
the future.  This could reflect a change in the quantity of an economic
resource.  It is also defined by its behavior in relation to the economic
resource.
"""
use Zenflows.DB.Schema

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
	Validate,
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
}

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
	field :resource_quantity_has_numerical_value, :float
	field :effort_quantity, :map, virtual: true
	belongs_to :effort_quantity_has_unit, Unit
	field :effort_quantity_has_numerical_value, :float
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
	timestamps()
end

@insert_reqr ~w[action_id provider_id receiver_id]a
@insert_cast @insert_reqr ++ ~w[
	has_beginning has_end has_point_in_time note
	at_location_id realization_of_id agreed_in triggered_by_id
]a

# insert changeset
@doc false
@spec chgset(params()) :: Changeset.t()
def chgset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @insert_cast)
	|> Changeset.validate_required(@insert_reqr)
	|> datetime_check()
	|> case do
		%{valid?: true, changes: %{action_id: action}} = cset ->
			do_chgset(action, Changeset.apply_changes(cset), params)
		cset ->
			cset
	end
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
end

@spec do_chgset(Action.ID.t(), Schema.t(), params()) :: Changeset.t()
defp do_chgset("raise", schema, params) do
	schema
	|> Changeset.cast(params, ~w[
		resource_conforms_to_id resource_inventoried_as_id
		resource_classified_as resource_quantity to_location_id
	]a)
	|> Changeset.validate_required([:resource_quantity])
	|> Measure.cast(:resource_quantity)
	|> require_agents_same()
	|> xor_required(:resource_conforms_to_id, :resource_inventoried_as_id)
end

defp do_chgset("produce", schema, params) do
	schema
	|> Changeset.cast(params, ~w[
		output_of_id resource_conforms_to_id resource_inventoried_as_id
		resource_classified_as resource_quantity to_location_id
	]a)
	|> Changeset.validate_required(~w[output_of_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
	|> require_agents_same()
	|> xor_required(:resource_conforms_to_id, :resource_inventoried_as_id)
end

defp do_chgset("lower", schema, params) do
	schema
	|> Changeset.cast(params, ~w[resource_inventoried_as_id resource_quantity]a)
	|> Changeset.validate_required(~w[resource_inventoried_as_id resource_quantity]a)
	|> require_agents_same()
	|> Measure.cast(:resource_quantity)
end

defp do_chgset("consume", schema, params) do
	schema
	|> Changeset.cast(params, ~w[input_of_id resource_inventoried_as_id resource_quantity]a)
	|> Changeset.validate_required(~w[input_of_id resource_inventoried_as_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
	|> require_agents_same()
end

defp do_chgset("use", schema, params) do
	schema
	|> Changeset.cast(params, ~w[
		input_of_id effort_quantity
		resource_inventoried_as_id resource_conforms_to_id
		resource_quantity
	]a)
	|> Changeset.validate_required(~w[input_of_id effort_quantity]a)
	|> Measure.cast(:effort_quantity)
	|> Measure.cast(:resource_quantity)
	|> xor_required(:resource_inventoried_as_id, :resource_conforms_to_id)
end

defp do_chgset("work", schema, params) do
	schema
	|> Changeset.cast(params, ~w[input_of_id effort_quantity resource_conforms_to_id]a)
	|> Changeset.validate_required(~w[input_of_id effort_quantity resource_conforms_to_id]a)
	|> Measure.cast(:effort_quantity)
end

defp do_chgset("cite", schema, params) do
	schema
	|> Changeset.cast(params, ~w[
		input_of_id resource_quantity
		resource_inventoried_as_id resource_conforms_to_id
	]a)
	|> Changeset.validate_required(~w[input_of_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
	|> xor_required(:resource_inventoried_as_id, :resource_conforms_to_id)
end

defp do_chgset("deliverService", schema, params) do
	schema
	|> Changeset.cast(params, ~w[input_of_id output_of_id resource_conforms_to_id]a)
	|> Changeset.validate_required(~w[resource_conforms_to_id]a)
	|> require_different_procs()
end

defp do_chgset("pickup", schema, params) do
	schema
	|> Changeset.cast(params, ~w[input_of_id resource_quantity resource_inventoried_as_id]a)
	|> Changeset.validate_required(~w[input_of_id resource_quantity resource_inventoried_as_id]a)
	|> Measure.cast(:resource_quantity)
	|> require_agents_same()
end

defp do_chgset("dropoff", schema, params) do
	schema
	|> Changeset.cast(params, ~w[output_of_id resource_quantity resource_inventoried_as_id to_location_id]a)
	|> Changeset.validate_required(~w[output_of_id resource_quantity resource_inventoried_as_id]a)
	|> Measure.cast(:resource_quantity)
	|> require_agents_same()
end

defp do_chgset("accept", schema, params) do
	schema
	|> Changeset.cast(params, ~w[input_of_id resource_quantity resource_inventoried_as_id]a)
	|> Changeset.validate_required(~w[input_of_id resource_quantity resource_inventoried_as_id]a)
	|> Measure.cast(:resource_quantity)
	|> require_agents_same()
end

defp do_chgset("modify", schema, params) do
	schema
	|> Changeset.cast(params, ~w[output_of_id resource_quantity resource_inventoried_as_id]a)
	|> Changeset.validate_required(~w[output_of_id resource_quantity resource_inventoried_as_id]a)
	|> Measure.cast(:resource_quantity)
	|> require_agents_same()
end

defp do_chgset("combine", schema, params) do
	schema
	|> Changeset.cast(params, ~w[]a)
	|> Changeset.validate_required(~w[]a)
end

defp do_chgset("separate", schema, params) do
	schema
	|> Changeset.cast(params, ~w[]a)
	|> Changeset.validate_required(~w[]a)
end

defp do_chgset("transferAllRights", schema, params) do
	schema
	|> Changeset.cast(params, ~w[resource_inventoried_as_id to_resource_inventoried_as_id resource_quantity]a)
	|> Changeset.validate_required(~w[resource_inventoried_as_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
end

defp do_chgset(action, schema, params) when action in ~w[transferCustody transfer] do
	schema
	|> Changeset.cast(params, ~w[resource_inventoried_as_id to_resource_inventoried_as_id resource_quantity to_location_id]a)
	|> Changeset.validate_required(~w[resource_inventoried_as_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
end

defp do_chgset("move", schema, params) do
	schema
	|> Changeset.cast(params, ~w[resource_inventoried_as_id to_resource_inventoried_as_id resource_quantity to_location_id]a)
	|> Changeset.validate_required(~w[resource_inventoried_as_id resource_quantity]a)
	|> Measure.cast(:resource_quantity)
	|> require_agents_same()
end

# Require that `:provider` and `:receiver` be the same agents.
@spec require_agents_same(Changeset.t()) :: Changeset.t()
defp require_agents_same(cset) do
	prov = cset.data.provider_id
	recv = cset.data.receiver_id

	# since provider and receiver is required, there's no nil case to care
	if prov != recv do
		msg = "agents must be the same"
		cset
		|> Changeset.add_error(:provider_id, msg)
		|> Changeset.add_error(:receiver_id, msg)
	else
		cset
	end
end

# Require either of the given fields `a` xor `b`.
@spec xor_required(Changeset.t(), atom(), atom()) :: Changeset.t()
defp xor_required(cset, a, b) do
	x = Changeset.get_change(cset, a)
	y = Changeset.get_change(cset, b)

	if (x && !y) || (!x && y) do
		cset
	else
		msg = "these are mutually exclusive and exactly one must be provided"

		cset
		|> Changeset.add_error(a, msg)
		|> Changeset.add_error(b, msg)
	end
end

# Require that `:input_of` and/or `:output_of` is required, and
# that they are not the same.
@spec require_different_procs(Changeset.t()) :: Changeset.t()
defp require_different_procs(cset) do
	input = Changeset.get_change(cset, :input_of_id)
	output = Changeset.get_change(cset, :output_of_id)

	cond do
		input != nil and output != nil and input == output ->
			msg = "must have different processes"

			cset
			|> Changeset.add_error(:input_of_id, msg)
			|> Changeset.add_error(:output_of_id, msg)

		input == nil and output == nil ->
			msg = "either of these must not be blank"

			cset
			|> Changeset.add_error(:input_of_id, msg)
			|> Changeset.add_error(:output_of_id, msg)

		true ->
			cset
	end
end

@update_cast ~w[note agreed_in realization_of_id triggered_by_id]a

# update changeset
@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema, params) do
	schema
	|> Changeset.cast(params, @update_cast)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:realization_of)
	|> Changeset.assoc_constraint(:triggered_by)
end

# Validate datetime mutual exclusivity and requirements.
# In other words, require one of these combinations to be provided:
#	* only :has_point_in_time
#   * only :has_beginning and/or :has_end
#
# This is only for inserting changeset.
@spec datetime_check(Changeset.t()) :: Changeset.t()
defp datetime_check(cset) do
	point = Changeset.get_change(cset, :has_point_in_time)
	begin = Changeset.get_change(cset, :has_beginning)
	endd = Changeset.get_change(cset, :has_end)

	cond do
		point && begin ->
			msg = "'has point in time' and 'has beginning' are mutually exclusive"

			cset
			|> Changeset.add_error(:has_point_in_time, msg)
			|> Changeset.add_error(:has_beginning, msg)

		point && endd ->
			msg = "'has point in time' and 'has end' are mutually exclusive"

			cset
			|> Changeset.add_error(:has_point_in_time, msg)
			|> Changeset.add_error(:has_end, msg)

		point || begin || endd ->
			cset

		true ->
			msg = "'has point in time', 'has beginning', or 'has end' is requried"

			cset
			|> Changeset.add_error(:has_beginning, msg)
			|> Changeset.add_error(:has_end, msg)
			|> Changeset.add_error(:has_point_in_time, msg)
	end
end
end
