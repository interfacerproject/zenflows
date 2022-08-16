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

defmodule Zenflows.VF.Intent.Type do
@moduledoc "GraphQL types of Intents."

use Absinthe.Schema.Notation

alias Zenflows.VF.Intent.Resolv

@action """
Relates an intent to a verb, such as consume, produce, work, improve, etc.
"""
@action_id "(`Action`) #{@action}"
@input_of "Defines the process to which this intent is an input."
@input_of_id "(`Process`) #{@input_of}"
@output_of "Defines the process to which this intent is an output."
@output_of_id "(`Process`) #{@output_of}"
@provider """
The economic agent from whom the intent is initiated.  This implies that
the intent is an offer.
"""
@provider_id "(`Agent`) #{@provider}"
@receiver """
The economic agent whom the intent is for.  This implies that the intent
is a request.
"""
@receiver_id "(`Agent`) #{@receiver}"
@resource_inventoried_as """
When a specific `EconomicResource` is known which can service the
`Intent`, this defines that resource.
"""
@resource_inventoried_as_id "(`EconomicResource`) #{@resource_inventoried_as}"
@resource_conforms_to """
The primary resource specification or definition of an existing or
potential economic resource.  A resource will have only one, as this
specifies exactly what the resource is.
"""
@resource_conforms_to_id "(`ResourceSpecification`) #{@resource_conforms_to}"
@resource_classified_as """
References a concept in a common taxonomy or other classification scheme
for purposes of categorization or grouping.
"""
@resource_quantity """
The amount and unit of the economic resource counted or inventoried.  This
is the quantity that could be used to increment or decrement a resource,
depending on the type of resource and resource effect of action.
"""
@effort_quantity """
The amount and unit of the work or use or citation effort-based action.
This is often a time duration, but also could be cycle counts or other
measures of effort or usefulness.
"""
@available_quantity "The total quantity of the offered resource available."
@has_beginning "The planned beginning of the intent."
@has_end "The planned end of the intent."
@has_point_in_time """
The planned date/time for the intent.  Can be used instead of beginning
and end.
"""
@due "The time something is expected to be complete."
@finished """
The intent is complete or not.  This is irrespective of if the original
goal has been met, and indicates that no more will be done.
"""
@at_location "The place where an intent would occur.  Usually mappable."
@at_location_id "(`SpatialThing`) #{@at_location}"
@image """
The base64-encoded image binary relevant to the intent, such as a photo.
"""
@name """
An informal or formal textual identifier for an intent.  Does not imply
uniqueness.
"""
@note "A textual description or comment."
@agreed_in """
Reference to an agreement between agents which specifies the rules or
policies or calculations which govern this intent.
"""
@deletable "The intent can be safely deleted, has no dependent information."

@desc """
A planned economic flow which has not been committed to, which can lead
to EconomicEvents (sometimes through Commitments).
"""
object :intent do
	field :id, non_null(:id)

	@desc @action
	field :action, non_null(:action), resolve: &Resolv.action/3

	@desc @input_of
	field :input_of, :process, resolve: &Resolv.input_of/3

	@desc @output_of
	field :output_of, :process, resolve: &Resolv.output_of/3

	@desc @provider
	field :provider, :agent, resolve: &Resolv.provider/3

	@desc @receiver
	field :receiver, :agent, resolve: &Resolv.receiver/3

	@desc @resource_inventoried_as
	field :resource_inventoried_as, :economic_resource,
		resolve: &Resolv.resource_inventoried_as/3

	@desc @resource_conforms_to
	field :resource_conforms_to, :economic_resource,
		resolve: &Resolv.resource_conforms_to/3

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @resource_quantity
	field :resource_quantity, :measure,
		resolve: &Resolv.resource_quantity/3

	@desc @effort_quantity
	field :effort_quantity, :measure,
		resolve: &Resolv.effort_quantity/3

	@desc @available_quantity
	field :available_quantity, :measure,
		resolve: &Resolv.available_quantity/3

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @has_point_in_time
	field :has_point_in_time, :datetime

	@desc @due
	field :due, :datetime

	@desc @finished
	field :finished, non_null(:boolean)

	@desc @at_location
	field :at_location, :spatial_thing, resolve: &Resolv.at_location/3

	@desc @image
	field :image, :base64

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @agreed_in
	field :agreed_in, :uri

	@desc @deletable
	field :deletable, non_null(:boolean)

	field :published_in, list_of(non_null(:proposed_intent)),
		resolve: &Resolv.published_in/3
end

object :intent_response do
	field :intent, non_null(:intent)
end

object :intent_edge do
	field :cursor, non_null(:string)
	field :node, non_null(:intent)
end

object :intent_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:intent_edge)))
end

input_object :intent_create_params do
	@desc @action_id
	field :action_id, non_null(:string), name: "action"

	@desc @input_of_id
	field :input_of_id, :id, name: "input_of"

	@desc @output_of_id
	field :output_of_id, :id, name: "output_of"

	@desc @provider_id
	field :provider_id, :id, name: "provider"

	@desc @receiver_id
	field :receiver_id, :id, name: "receiver"

	@desc @resource_inventoried_as_id
	field :resource_inventoried_as_id, :id, name: "resource_inventoried_as"

	@desc @resource_conforms_to_id
	field :resource_conforms_to_id, :id, name: "resource_conforms_to"

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @resource_quantity
	field :resource_quantity, :imeasure

	@desc @effort_quantity
	field :effort_quantity, :imeasure

	@desc @available_quantity
	field :available_quantity, :imeasure

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @has_point_in_time
	field :has_point_in_time, :datetime

	@desc @due
	field :due, :datetime

	@desc @finished
	field :finished, :boolean

	@desc @at_location_id
	field :at_location_id, :id, name: "at_location"

	@desc @image
	field :image, :base64

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @agreed_in
	field :agreed_in, :uri
end

input_object :intent_update_params do
	field :id, non_null(:id)

	@desc @action_id
	field :action_id, :string, name: "action"

	@desc @input_of_id
	field :input_of_id, :id, name: "input_of"

	@desc @output_of_id
	field :output_of_id, :id, name: "output_of"

	@desc @provider_id
	field :provider_id, :id, name: "provider"

	@desc @receiver_id
	field :receiver_id, :id, name: "receiver"

	@desc @resource_inventoried_as_id
	field :resource_inventoried_as_id, :id, name: "resource_inventoried_as"

	@desc @resource_conforms_to_id
	field :resource_conforms_to_id, :id, name: "resource_conforms_to"

	@desc @resource_classified_as
	field :resource_classified_as, list_of(non_null(:uri))

	@desc @resource_quantity
	field :resource_quantity, :imeasure

	@desc @effort_quantity
	field :effort_quantity, :imeasure

	@desc @available_quantity
	field :available_quantity, :imeasure

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @has_point_in_time
	field :has_point_in_time, :datetime

	@desc @due
	field :due, :datetime

	@desc @finished
	field :finished, :boolean

	@desc @at_location_id
	field :at_location_id, :id, name: "at_location"

	@desc @image
	field :image, :base64

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @agreed_in
	field :agreed_in, :uri
end

object :query_intent do
	field :intent, :intent do
		arg :id, non_null(:id)
		resolve &Resolv.intent/2
	end

	field :intents, non_null(:intent_connection) do
		arg :first, :integer
		arg :after, :string
		arg :last, :integer
		arg :before, :string
		resolve &Resolv.intents/2
	end
end

object :mutation_intent do
	field :create_intent, non_null(:intent_response) do
		arg :intent, non_null(:intent_create_params)
		resolve &Resolv.create_intent/2
	end

	field :update_intent, non_null(:intent_response) do
		arg :intent, non_null(:intent_update_params)
		resolve &Resolv.update_intent/2
	end

	field :delete_intent, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_intent/2
	end
end
end
