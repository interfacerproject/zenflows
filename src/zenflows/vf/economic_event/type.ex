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

defmodule Zenflows.VF.EconomicEvent.Type do
@moduledoc "GraphQL types of EconomicEvents."

use Absinthe.Schema.Notation

alias Zenflows.VF.EconomicEvent.Resolv

@action """
Relates an economic event to a verb, such as consume, produce, work,
improve, etc.
"""
@input_of "Defines the process to which this event is an input."
@input_of_id "(`Process`) #{@input_of}"
@output_of "Defines the process to which this event is an output."
@output_of_id "(`Process`) #{@output_of}"
@provider """
The economic agent from whom the actual economic event is initiated.
"""
@provider_id "(`Agent`) #{@provider}"
@receiver "The economic agent whom the actual economic event is for."
@receiver_id "(`Agent`) #{@receiver}"
@resource_inventoried_as """
Economic resource involved in the economic event.
"""
@resource_inventoried_as_id """
(`EconomicResource`) #{@resource_inventoried_as}
"""
@to_resource_inventoried_as """
Additional economic resource on the economic event when needed by the
receiver.  Used when a transfer or move, or sometimes other actions,
requires explicitly identifying an economic resource on the receiving
side.
"""
@to_resource_inventoried_as_id """
(`EconomicResource`) #{@to_resource_inventoried_as}
"""
@resource_classified_as """
References a concept in a common taxonomy or other classification scheme
for purposes of categorization or grouping.
"""
@resource_conforms_to """
The primary resource specification or definition of an existing or
potential economic resource.  A resource will have only one, as this
specifies exactly what the resource is.
"""
@resource_conforms_to_id """
(`ResourceSpecification`) #{@resource_conforms_to}
"""
@resource_quantity """
The amount and unit of the economic resource counted or inventoried.
This is the quantity that could be used to increment or decrement a
resource, depending on the type of resource and resource effect of action.
"""
@effort_quantity """
The amount and unit of the work or use or citation effort-based action.
This is often a time duration, but also could be cycle counts or other
measures of effort or usefulness.
"""
@has_beginning "The beginning of the economic event."
@has_end "The end of the economic event."
@has_point_in_time """
The date/time at which the economic event occurred.  Can be used instead of beginning and end."
"""
@note "A textual description or comment."
@to_location "The new location of the receiver resource."
@to_location_id "(`SpatialThing`) #{@to_location}"
@at_location "The place where an economic event occurs.  Usually mappable."
@at_location_id "(`SpatialThing`) #{@at_location}"
@realization_of "This economic event occurs as part of this agreement."
@realization_of_id "(`Agreement`) #{@realization_of}"
#@in_scope_of """
#Grouping around something to create a boundary or context, used for
#documenting, accounting, planning.
#"""
@agreed_in """
Reference to an agreement between agents which specifies the rules or
policies or calculations which govern this economic event.
"""
@triggered_by "References another economic event that implied this economic event, often based on a prior agreement."
@triggered_by_id "(`EconomicEvent`) #{@triggered_by}"

@desc """
An observed economic flow, as opposed to a flow planned to happen in
the future.  This could reflect a change in the quantity of an economic
resource.  It is also defined by its behavior in relation to the economic
resource (see `Action`).
"""
object :economic_event do
	field :id, non_null(:id)

	@desc @action
	field :action, non_null(:action), resolve: &Resolv.action/3

	@desc @input_of
	field :input_of, :process, resolve: &Resolv.input_of/3

	@desc @output_of
	field :output_of, :process, resolve: &Resolv.output_of/3

	@desc @provider
	field :provider, non_null(:agent), resolve: &Resolv.provider/3

	@desc @receiver
	field :receiver, non_null(:agent), resolve: &Resolv.receiver/3

	@desc @resource_inventoried_as
	field :resource_inventoried_as, :economic_resource,
		resolve: &Resolv.resource_inventoried_as/3

	@desc @to_resource_inventoried_as
	field :to_resource_inventoried_as, :economic_resource,
		resolve: &Resolv.to_resource_inventoried_as/3

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @resource_conforms_to
	field :resource_conforms_to, :resource_specification,
		resolve: &Resolv.resource_conforms_to/3

	@desc @resource_quantity
	field :resource_quantity, :measure,
		resolve: &Resolv.resource_quantity/3

	@desc @effort_quantity
	field :effort_quantity, :measure,
		resolve: &Resolv.effort_quantity/3

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @has_point_in_time
	field :has_point_in_time, :datetime

	@desc @note
	field :note, :string

	@desc @to_location
	field :to_location, :spatial_thing, resolve: &Resolv.to_location/3

	@desc @at_location
	field :at_location, :spatial_thing, resolve: &Resolv.at_location/3

	@desc @realization_of
	field :realization_of, :agreement,
		resolve: &Resolv.realization_of/3

	@desc @agreed_in
	field :agreed_in, :string

	@desc @triggered_by
	field :triggered_by, :economic_event,
		resolve: &Resolv.triggered_by/3
end

object :economic_event_response do
	@desc "Details of the newly created event."
	field :economic_event, non_null(:economic_event)

	#@desc """
	#Details of any newly created `EconomicResource`, for events that
	#create new resources.
	#"""
	#field :economic_resource, :economic_resource
end

input_object :economic_event_create_params do
	@desc @action
	field :action_id, non_null(:string), name: "action"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @input_of_id
	field :input_of_id, :id, name: "input_of"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @output_of_id
	field :output_of_id, :id, name: "output_of"

	@desc @provider_id
	field :provider_id, :id, name: "provider"

	@desc @receiver_id
	field :receiver_id, :id, name: "receiver"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @resource_inventoried_as_id
	field :resource_inventoried_as_id, :id, name: "resource_inventoried_as"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @to_resource_inventoried_as_id
	field :to_resource_inventoried_as_id, :id, name: "to_resource_inventoried_as"

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @resource_conforms_to_id
	field :resource_conforms_to_id, :id, name: "resource_conforms_to"

	@desc @resource_quantity
	field :resource_quantity, :imeasure

	@desc @effort_quantity
	field :effort_quantity, :imeasure

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @has_point_in_time
	field :has_point_in_time, :datetime

	@desc @note
	field :note, :string

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @to_location_id
	field :to_location_id, :id, name: "to_location"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @at_location_id
	field :at_location_id, :id, name: "at_location"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @realization_of_id
	field :realization_of_id, :id, name: "realization_of"

	@desc @agreed_in
	field :agreed_in, :string

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @triggered_by_id
	field :triggered_by_id, :id, name: "triggered_by"
end

input_object :economic_event_update_params do
	field :id, non_null(:id)

	@desc @note
	field :note, :string

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @realization_of_id
	field :realization_of_id, :id, name: "realization_of"

	@desc @agreed_in
	field :agreed_in, :string

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc @triggered_by_id
	field :triggered_by_id, :id, name: "triggered_by"
end

object :query_economic_event do
	field :economic_event, :economic_event do
		arg :id, non_null(:id)
		resolve &Resolv.economic_event/2
	end

	#recipeFlow(start: ID, limit: Int): [EconomicEvent!]
end

object :mutation_economic_event do
	field :create_economic_event, non_null(:economic_event_response) do
		arg :event, non_null(:economic_event_create_params)
		arg :new_inventoried_resource, :economic_resource_create_params
		resolve &Resolv.create_economic_event/2
	end

	field :update_economic_event, non_null(:economic_event_response) do
		arg :event, non_null(:economic_event_update_params)
		resolve &Resolv.update_economic_event/2
	end
end
end
