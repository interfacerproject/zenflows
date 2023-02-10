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

defmodule Zenflows.VF.Organization.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.Organization.Resolv

@name "The name that this agent will be referred to by."
@images """
The image files relevant to the agent, such as a logo, avatar, photo, etc.
"""
@primary_location """
The main place an agent is located, often an address where activities
occur and mail can be sent.	 This is usually a mappable geographic
location.  It also could be a website address, as in the case of agents
who have no physical location.
"""
@primary_location_id "(`SpatialThing`) #{@primary_location}"
@note "A textual description or comment."
@classified_as """
References one or more concepts in a common taxonomy or other
classification scheme for purposes of categorization or grouping.
"""

@desc "A formal or informal group, or legal organization."
object :organization do
	interface :agent

	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @images
	field :images, list_of(non_null(:file))

	@desc @primary_location
	field :primary_location, :spatial_thing,
		resolve: &Resolv.primary_location/3

	@desc @note
	field :note, :string

	@desc @classified_as
	field :classified_as, list_of(non_null(:string))
end

input_object :organization_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @images
	field :images, list_of(non_null(:ifile)), resolve: &Resolv.images/3

	@desc @note
	field :note, :string

	@desc @primary_location_id
	field :primary_location_id, :id, name: "primary_location"

	@desc @classified_as
	field :classified_as, list_of(non_null(:string))
end

input_object :organization_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @primary_location_id
	field :primary_location_id, :id, name: "primary_location"

	@desc @classified_as
	field :classified_as, list_of(non_null(:string))
end

object :organization_response do
	field :agent, non_null(:organization)
end

object :organization_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:organization)
end

object :organization_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:organization_edge)))
end

input_object :organization_filter_params do
	field :name, :string
end

object :query_organization do
	@desc "Find an organization (group) agent by its ID."
	field :organization, :organization do
		arg :id, non_null(:id)
		resolve &Resolv.organization/2
	end

	@desc """
	Loads all organizations publicly registered within this
	collaboration space.
	"""
	field :organizations, :organization_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		arg :filter, :organization_filter_params
		resolve &Resolv.organizations/2
	end
end

object :mutation_organization do
	@desc """
	Registers a new organization (group agent) with the
	collaboration space.
	"""
	field :create_organization, non_null(:organization_response) do
		arg :organization, non_null(:organization_create_params)
		resolve &Resolv.create_organization/2
	end

	@desc "Update organization profile details."
	field :update_organization, non_null(:organization_response) do
		arg :organization, non_null(:organization_update_params)
		resolve &Resolv.update_organization/2
	end

	@desc """
	Erase record of an organization and thus remove it from
	the collaboration space.
	"""
	field :delete_organization, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_organization/2
	end
end
end
