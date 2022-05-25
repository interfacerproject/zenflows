defmodule Zenflows.VF.EconomicResource.Type do
@moduledoc "GraphQL types of EconomicResources."

use Absinthe.Schema.Notation

alias Zenflows.VF.EconomicResource.Resolv

@name """
An informal or formal textual identifier for an item.  Does not imply
uniqueness.
"""
@note "A textual description or comment."
@image """
The URI to an image relevant to the entity, such as a photo, diagram, etc.
"""
@tracking_identifier """
Sometimes called serial number, used when each item must have a traceable
identifier (like a computer).  Could also be used for other unique
tracking identifiers needed for resources.
"""
@classified_as """
References one or more concepts in a common taxonomy or other
classification scheme for purposes of categorization or grouping.
"""
@conforms_to """
The primary resource specification or definition of an existing or
potential economic resource.  A resource will have only one, as this
specifies exactly what the resource is.
"""
@accounting_quantity """
The current amount and unit of the economic resource for which the
agent has primary rights and responsibilities, sometimes thought of as
ownership.  This can be either stored or derived from economic events
affecting the resource.
"""
@onhand_quantity """
The current amount and unit of the economic resource which is under
direct control of the agent.  It may be more or less than the accounting
quantity.  This can be either stored or derived from economic events
affecting the resource.
"""
@primary_accountable """
The agent currently with primary rights and responsibilites for
the economic resource.  It is the agent that is associated with the
accountingQuantity of the economic resource.
"""
@custodian """
The agent who holds the physical custody of this resource.  It is the
agent that is associated with the onhandQuantity of the economic resource.
"""
@stage """
References the ProcessSpecification of the last process the desired
economic resource went through.  Stage is used when the last process
is important for finding proper resources, such as where the publishing
process wants only documents that have gone through the editing process.
"""
@state """
The state of the desired economic resource (pass or fail), after coming
out of a test or review process.  Can be derived from the last event if
a pass or fail event.
"""
@current_location """
The current place an economic resource is located.  Could be at any
level of granularity, from a town to an address to a warehouse location.
Usually mappable.
"""
@lot """
Lot or batch of an economic resource, used to track forward or backwards
to all occurrences of resources of that lot.  Note more than one resource
can be of the same lot.
"""
@lot_id "(`ProductBatch`) #{@lot}"
@contained_in """
Used when a stock economic resource contains items also defined as
economic resources.
"""
@unit_of_effort """
The unit used for use or work or cite actions for this resource.
"""

@desc "A resource which is useful to people or the ecosystem."
object :economic_resource do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @image
	field :image, :uri

	@desc @tracking_identifier
	field :tracking_identifier, :string

	@desc @classified_as
	field :classified_as, list_of(non_null(:uri))

	@desc @conforms_to
	field :conforms_to, non_null(:resource_specification),
		resolve: &Resolv.conforms_to/3

	@desc @accounting_quantity
	field :accounting_quantity, non_null(:measure),
		resolve: &Resolv.accounting_quantity/3

	@desc @onhand_quantity
	field :onhand_quantity, non_null(:measure),
		resolve: &Resolv.onhand_quantity/3

	@desc @primary_accountable
	field :primary_accountable, non_null(:agent),
		resolve: &Resolv.primary_accountable/3

	@desc @custodian
	field :custodian, non_null(:agent),
		resolve: &Resolv.custodian/3

	@desc @stage
	field :stage, :process_specification, resolve: &Resolv.stage/3

	@desc @state
	field :state, :action, resolve: &Resolv.state/3

	@desc @current_location
	field :current_location, :spatial_thing,
		resolve: &Resolv.current_location/3

	@desc @lot
	field :lot, :product_batch, resolve: &Resolv.lot/3

	@desc @contained_in
	field :contained_in, :economic_resource,
		resolve: &Resolv.contained_in/3

	@desc @unit_of_effort
	field :unit_of_effort, :unit, resolve: &Resolv.unit_of_effort/3
end

object :economic_resource_response do
	field :economic_resource, non_null(:economic_resource)
end

input_object :economic_resource_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @image
	field :image, :uri

	@desc @tracking_identifier
	field :tracking_identifier, :string

	@desc @lot_id
	field :lot_id, :id, name: "lot"
end

input_object :economic_resource_update_params do
	field :id, non_null(:id)

	@desc @note
	field :note, :string

	@desc @image
	field :image, :uri
end

object :query_economic_resource do
	field :economic_resource, :economic_resource do
		arg :id, non_null(:id)
		resolve &Resolv.economic_resource/2
	end

	#economicResources(start: ID, limit: Int): [EconomicResource!]
end

object :mutation_economic_resource do
	field :update_economic_resource, non_null(:economic_resource_response) do
		arg :resource, non_null(:economic_resource_update_params)
		resolve &Resolv.update_economic_resource/2
	end

	field :delete_economic_resource, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_economic_resource/2
	end
end
end
