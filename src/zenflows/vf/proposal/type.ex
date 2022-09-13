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

defmodule Zenflows.VF.Proposal.Type do
@moduledoc "GraphQL types of Proposals."

use Absinthe.Schema.Notation

alias Zenflows.VF.Proposal.Resolv

@name  """
An informal or formal textual identifier for a proposal.  Does not
imply uniqueness.
"""
@note "A textual description or comment."
@has_beginning "The beginning time of proposal publication."
@has_end "The end time of proposal publication."
@unit_based """
This proposal contains unit based quantities, which can be multipied to
create commitments; commonly seen in a price list or e-commerce.
"""
@created "The date and time the proposal was created."
@eligible_location "The location at which this proposal is eligible."
@eligible_location_id "(`SpatialThing`) #{@eligible_location}"

@desc """
Published requests or offers, sometimes with what is expected in return.
"""
object :proposal do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @unit_based
	field :unit_based, :boolean

	@desc @created
	field :inserted_at, :datetime, name: "created"

	@desc @eligible_location
	field :eligible_location, :spatial_thing, resolve: &Resolv.eligible_location/3

	field :publishes, list_of(non_null(:proposed_intent)),
		resolve: &Resolv.publishes/3

	field :primary_intents, list_of(non_null(:intent)),
		resolve: &Resolv.primary_intents/3

	field :reciprocal_intents, list_of(non_null(:intent)),
		resolve: &Resolv.reciprocal_intents/3
end

input_object :proposal_create_params do
	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @unit_based
	field :unit_based, :boolean

	@desc @eligible_location_id
	field :eligible_location_id, :id, name: "eligible_location"
end

input_object :proposal_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @unit_based
	field :unit_based, :boolean

	@desc @eligible_location_id
	field :eligible_location_id, :id, name: "eligible_location"
end

object :proposal_response do
	field :proposal, non_null(:proposal)
end

object :proposal_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:proposal)
end

object :proposal_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:proposal_edge)))
end

object :query_proposal do
	field :proposal, :proposal do
		arg :id, non_null(:id)
		resolve &Resolv.proposal/2
	end

	field :proposals, non_null(:proposal_connection) do
		meta only_guest?: true
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.proposals/2
	end

	@desc "List all proposals that are being listed as offers."
	field :offers, non_null(:proposal_connection) do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.offers/2
	end

	@desc "List all proposals that are being listed as requests."
	field :requests, non_null(:proposal_connection) do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.offers/2
	end
end

object :mutation_proposal do
	field :create_proposal, non_null(:proposal_response) do
		arg :proposal, non_null(:proposal_create_params)
		resolve &Resolv.create_proposal/2
	end

	field :update_proposal, non_null(:proposal_response) do
		arg :proposal, non_null(:proposal_update_params)
		resolve &Resolv.update_proposal/2
	end

	field :delete_proposal, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_proposal/2
	end
end
end
