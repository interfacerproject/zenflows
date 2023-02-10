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

defmodule Zenflows.VF.EconomicResource.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.EconomicResource.Resolv

@name """
An informal or formal textual identifier for an item.  Does not imply
uniqueness.
"""
@note "A textual description or comment."
@images """
The image files relevant to the entity, such as a photo, diagram, etc.
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
@okhv "The okh version of the standard of the manifest."
@licensor "States who is licensing the project."
@license "States the licenses under which the project is made available."
@repo "A URL to the repository of the project."
@version "The version of the project."
@metadata "Metadata of the project."

@desc "A resource which is useful to people or the ecosystem."
object :economic_resource do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @images
	field :images, list_of(non_null(:file)), resolve: &Resolv.images/3

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

	@desc @okhv
	field :okhv, :string

	@desc @repo
	field :repo, :string

	@desc @version
	field :version, :string

	@desc @licensor
	field :licensor, :string

	@desc @license
	field :license, :string

	@desc @metadata
	field :metadata, :json

	@desc "Used to implement the trace algorithm."
	field :previous, list_of(non_null(:economic_event)),
		resolve: &Resolv.previous/3

	field :trace, list_of(non_null(:track_trace_item)),
		resolve: &Resolv.trace/3

	field :trace_dpp, non_null(:json), resolve: &Resolv.trace_dpp/3
end

input_object :economic_resource_create_params do
	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @images
	field :images, list_of(non_null(:ifile))

	@desc @tracking_identifier
	field :tracking_identifier, :string

	@desc @lot_id
	field :lot_id, :id, name: "lot"

	@desc @okhv
	field :okhv, :string

	@desc @repo
	field :repo, :string

	@desc @version
	field :version, :string

	@desc @licensor
	field :licensor, :string

	@desc @license
	field :license, :string

	@desc @metadata
	field :metadata, :json
end

input_object :economic_resource_update_params do
	field :id, non_null(:id)

	@desc @note
	field :note, :string

	@desc @metadata
	field :metadata, :json
end

object :economic_resource_response do
	field :economic_resource, non_null(:economic_resource)
end

object :economic_resource_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:economic_resource)
end

object :economic_resource_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:economic_resource_edge)))
end

input_object :economic_resource_filter_params do
	field :id, list_of(non_null(:id))
	field :or_id, list_of(non_null(:id))
	field :classified_as, list_of(non_null(:uri))
	field :or_classified_as, list_of(non_null(:uri))
	field :conforms_to, list_of(non_null(:id))
	field :or_conforms_to, list_of(non_null(:id))
	field :primary_accountable, list_of(non_null(:id))
	field :or_primary_accountable, list_of(non_null(:id))
	field :not_primary_accountable, list_of(non_null(:id))
	field :custodian, list_of(non_null(:id))
	field :or_custodian, list_of(non_null(:id))
	field :not_custodian, list_of(non_null(:id))
	field :gt_onhand_quantity_has_numerical_value, :decimal
	field :or_gt_onhand_quantity_has_numerical_value, :decimal
	field :name, :string
	field :or_name, :string
	field :note, :string
	field :or_note, :string
	field :repo, :string
	field :or_repo, :string
end

object :query_economic_resource do
	field :economic_resource, :economic_resource do
		meta only_guest?: true
		arg :id, non_null(:id)
		resolve &Resolv.economic_resource/2
	end

	field :economic_resources, :economic_resource_connection do
		meta only_guest?: true
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		arg :filter, :economic_resource_filter_params
		resolve &Resolv.economic_resources/2
	end

	field :economic_resource_classifications, list_of(non_null(:uri)) do
		resolve &Resolv.economic_resource_classifications/2
	end
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
