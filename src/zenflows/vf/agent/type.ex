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

defmodule Zenflows.VF.Agent.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.{Agent, Agent.Resolv}
@name """
An informal or formal textual identifier for an agent.  Does not imply
uniqueness.
"""
@images """
The image files relevant to the agent, such as a logo, avatar, photo, etc.
"""
@note "A textual description or comment."
@primary_location """
The main place an agent is located, often an address where activities
occur and mail can be sent.  This is usually a mappable geographic
location.  It also could be a website address, as in the case of agents
who have no physical location.
"""
@classified_as """
References one or more concepts in a common taxonomy or other
classification scheme for purposes of categorization or grouping.
"""

@desc "A person or group or organization with economic agency."
interface :agent do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @images
	field :images, list_of(non_null(:file)), resolve: &Resolv.images/3

	@desc @note
	field :note, :string

	@desc @primary_location
	field :primary_location, :spatial_thing,
		resolve: &Resolv.primary_location/3

	@desc @classified_as
	field :classified_as, list_of(non_null(:uri))

	resolve_type fn
		%Agent{type: :per}, _ -> :person
		%Agent{type: :org}, _ -> :organization
		nil, _ -> nil
	end
end

object :agent_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:agent)
end

object :agent_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:agent_edge)))
end

input_object :agent_filter_params do
	field :name, :string
end

object :query_agent do
	@desc "Loads details of the currently authenticated agent."
	field :my_agent, :agent do
		resolve &Resolv.my_agent/2
	end

	@desc "Find an agent (person or organization) by their ID."
	field :agent, :agent do
		arg :id, non_null(:id)
		resolve &Resolv.agent/2
	end

	@desc """
	Loads all agents publicly registered within this collaboration
	space.
	"""
	field :agents, :agent_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		arg :filter, :agent_filter_params
		resolve &Resolv.agents/2
	end
end

# object :mutation_agent
end
