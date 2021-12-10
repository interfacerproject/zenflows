defmodule Zenflows.Valflow.EconomicEvent do
@moduledoc """
An observed economic flow, as opposed to a flow planned to happen in
the future.  This could reflect a change in the quantity of an economic
resource.  It is also defined by its behavior in relation to the economic
resource.
"""
use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	ActionEnum,
	Agent,
	Agreement,
	EconomicEvent,
	EconomicResource,
	Measure,
	Process,
	ResourceSpecification,
	SpatialThing,
	Validate,
}

@type t() :: %__MODULE__{
	action: ActionEnum.t(),
	provider: Agent.t(),
	receiver: Agent.t(),
	input_of: Process.t() | nil,
	output_of: Process.t() | nil,
	resource_inventoried_as: EconomicResource.t() | nil,
	to_resource_inventoried_as: EconomicResource.t() | nil,
	resource_classified_as: [String.t()] | nil,
	resource_conforms_to: ResourceSpecification.t() | nil,
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	realization_of: Agreement.t() | nil,
	at_location: SpatialThing.t() | nil,
	has_beginning: DateTime.t() | nil,
	has_end: DateTime.t() | nil,
	has_point_in_time: DateTime.t() | nil,
	note: String.t() | nil,
	# in_scope_of:
	agreed_in: String.t() | nil,
	triggered_by: EconomicEvent.t(),
}

schema "vf_economic_event" do
	field :action, ActionEnum
	belongs_to :provider, Agent
	belongs_to :receiver, Agent
	belongs_to :input_of, Process
	belongs_to :output_of, Process
	belongs_to :resource_inventoried_as, EconomicResource
	belongs_to :to_resource_inventoried_as, EconomicResource
	field :resource_classified_as, {:array, :string}
	belongs_to :resource_conforms_to, ResourceSpecification
	belongs_to :resource_quantity, Measure
	belongs_to :effort_quantity, Measure
	belongs_to :realization_of, Agreement
	belongs_to :at_location, SpatialThing
	field :has_beginning, :utc_datetime_usec
	field :has_end, :utc_datetime_usec
	field :has_point_in_time, :utc_datetime_usec
	field :note, :string
	# field :in_scope_of
	field :agreed_in, :string
	belongs_to :triggered_by, EconomicEvent
end

@insert_reqr ~w[action provider_id receiver_id]a
@insert_cast @insert_reqr ++ ~w[
	input_of_id output_of_id
	resource_inventoried_as_id to_resource_inventoried_as_id
	resource_classified_as resource_conforms_to_id
	resource_quantity_id effort_quantity_id realization_of_id
	at_location_id has_beginning has_end has_point_in_time
	note agreed_in triggered_by_id
]a
@update_cast ~w[note agreed_in realization_of_id]a

# insert changeset
@doc false
@spec chset(params()) :: Changeset.t()
def chset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @insert_cast)
	|> Changeset.validate_required(@insert_reqr)
	|> datetime_check()
	|> resource_check()
	|> Validate.note(:note)
	|> Validate.class(:resource_classified_as)
	|> Changeset.assoc_constraint(:provider)
	|> Changeset.assoc_constraint(:receiver)
	|> Changeset.assoc_constraint(:input_of)
	|> Changeset.assoc_constraint(:output_of)
	|> Changeset.assoc_constraint(:resource_inventoried_as)
	|> Changeset.assoc_constraint(:to_resource_inventoried_as)
	|> Changeset.assoc_constraint(:resource_conforms_to)
	|> Changeset.assoc_constraint(:resource_quantity)
	|> Changeset.assoc_constraint(:effort_quantity)
	|> Changeset.assoc_constraint(:realization_of)
	|> Changeset.assoc_constraint(:at_location)
	|> Changeset.assoc_constraint(:triggered_by)
end

# update changeset
@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema, params) do
	schema
	|> Changeset.cast(params, @update_cast)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:realization_of)
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
			msg = "has_point_in_time and has_beginning are mutually exclusive"

			cset
			|> Changeset.add_error(:has_point_in_time, msg)
			|> Changeset.add_error(:has_beginning, msg)

		point && endd ->
			msg = "has_point_in_time and has_end are mutually exclusive"

			cset
			|> Changeset.add_error(:has_point_in_time, msg)
			|> Changeset.add_error(:has_end, msg)

		point || begin || endd ->
			cset

		true ->
			msg = "has_point_in_time or has_beginning or has_end is requried"

			cset
			|> Changeset.add_error(:has_beginning, msg)
			|> Changeset.add_error(:has_end, msg)
			|> Changeset.add_error(:has_point_in_time, msg)
	end
end

# Validate mutual exclusivity of having an actual resource or its
# specification.
# In other words, forbid the following cases to be provided:
#	* :resource_conforms_to and :resource_inventoried_as
#   * :resource_conforms_to and :to_resource_inventoried_as
#
# This is only for inserting changeset.
@spec resource_check(Changeset.t()) :: Changeset.t()
defp resource_check(cset) do
	res_con = Changeset.get_change(cset, :resource_conforms_to_id)
	res_inv = Changeset.get_change(cset, :resource_inventoried_as_id)
	to_res_inv = Changeset.get_change(cset, :to_resource_inventoried_as_id)

	cond do
		res_con && res_inv ->
			msg = "resource_conforms_to and resource_inventoried_as are mutually exclusive"

			cset
			|> Changeset.add_error(:resource_conforms_to_id, msg)
			|> Changeset.add_error(:resource_inventoried_as_id, msg)
		res_con && to_res_inv ->
			msg = "resource_conforms_to and to_resource_inventoried_as are mutually exclusive"

			cset
			|> Changeset.add_error(:resource_conforms_to_id, msg)
			|> Changeset.add_error(:to_resource_inventoried_as_id, msg)

		true ->
			cset
	end
end
end
