# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.VF.Satisfaction.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.Satisfaction.Resolv

@note "A textual description or comment."
@satisfies """
An intent satisfied fully or partially by an economic event or commitment.
"""
@satisfies_id "(`Intent`) #{@satisfies}"
@satisfied_by_event """
An economic event fully or partially satisfying an intent.

Mutually exclusive with commitment.
"""
@satisfied_by_event_id "(`EconomicEvent`) #{@satisfied_by_event}"
#@satisfied_by_commitment """
#A commitment fully or partially satisfying an intent."
#
#Mutually exclusive with event.
#"""
#@satisfied_by_commitment_id "(`Commitment`) #{@satisfied_by_commitment}"
@resource_quantity """
The amount and unit of the economic resource counted or inventoried.
"""
@effort_quantity """
The amount and unit of the work or use or citation effort-based
action.  This is often a time duration, but also could be cycle
counts or other measures of effort or usefulness.
"""

@desc """
Represents many-to-many relationships between intents and commitments
or events that partially or full satisfy one or more intents.
"""
object :satisfaction do
	field :id, non_null(:id)

	@desc @note
	field :note, :string

	@desc @satisfies
	field :satisfies, non_null(:intent), resolve: &Resolv.satisfies/3

	@desc @satisfied_by_event
	field :satisfied_by_event, :economic_event,
		resolve: &Resolv.satisfied_by_event/3

	#@desc @satisfied_by_commitment
	#field :satisfied_by_commitment, :commitment,
	#	resolve: &Resolv.satisfied_by_commitment/3

	@desc @resource_quantity
	field :resource_quantity, :measure, resolve: &Resolv.resource_quantity/3

	@desc @effort_quantity
	field :effort_quantity, :measure, resolve: &Resolv.effort_quantity/3
end

input_object :satisfaction_create_params do
	@desc @note
	field :note, :string

	@desc @satisfies_id
	field :satisfies_id, non_null(:id), name: "satisfies"

	@desc @satisfied_by_event_id
	field :satisfied_by_event_id, :id, name: "satisfied_by_event"

	#@desc @satisfied_by_commitment_id
	#field :satisfied_by_commitment_id, :id, name: "satisfied_by_commitment"

	@desc @resource_quantity
	field :resource_quantity, :imeasure

	@desc @effort_quantity
	field :effort_quantity, :imeasure
end

input_object :satisfaction_update_params do
	field :id, non_null(:id)

	@desc @note
	field :note, :string

	@desc @satisfies_id
	field :satisfies_id, :id, name: "satisfies"

	@desc @satisfied_by_event_id
	field :satisfied_by_event_id, :id, name: "satisfied_by_event"

	#@desc @satisfied_by_commitment_id
	#field :satisfied_by_commitment_id, :id, name: "satisfied_by_commitment"

	@desc @resource_quantity
	field :resource_quantity, :imeasure

	@desc @effort_quantity
	field :effort_quantity, :imeasure
end

object :satisfaction_response do
	field :satisfaction, non_null(:satisfaction)
end

object :satisfaction_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:satisfaction)
end

object :satisfaction_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:satisfaction_edge)))
end

object :query_satisfaction do
	field :satisfaction, :satisfaction do
		arg :id, non_null(:id)
		resolve &Resolv.satisfaction/2
	end

	field :satisfactions, non_null(:satisfaction_connection) do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.satisfactions/2
	end
end

object :mutation_satisfaction do
	field :create_satisfaction, non_null(:satisfaction_response) do
		arg :satisfaction, non_null(:satisfaction_create_params)
		resolve &Resolv.create_satisfaction/2
	end

	field :update_satisfaction, non_null(:satisfaction_response) do
		arg :satisfaction, non_null(:satisfaction_update_params)
		resolve &Resolv.update_satisfaction/2
	end

	field :delete_satisfaction, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_satisfaction/2
	end
end
end
