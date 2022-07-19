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

defmodule Zenflows.VF.Agent.Type do
@moduledoc "GraphQL types of Agents."

use Absinthe.Schema.Notation

alias Zenflows.VF.{Agent, Agent.Resolv}
@name """
An informal or formal textual identifier for an agent.  Does not imply
uniqueness.
"""
@image """
The URI to an image relevant to the agent, such as a logo, avatar,
photo, etc.
"""
@note "A textual description or comment."
@primary_location """
The main place an agent is located, often an address where activities
occur and mail can be sent.  This is usually a mappable geographic
location.  It also could be a website address, as in the case of agents
who have no physical location.
"""

@desc "A person or group or organization with economic agency."
interface :agent do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @image
	field :image, :uri

	@desc @note
	field :note, :string

	@desc @primary_location
	field :primary_location, :spatial_thing,
		resolve: &Resolv.primary_location/3

	resolve_type fn
		%Agent{type: :per}, _ -> :person
		%Agent{type: :org}, _ -> :organization
		nil, _ -> nil
	end
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

	#"Loads all agents publicly registered within this collaboration space."
	#agents(start: ID, limit: Int): [Agent!]
end

# object :mutation_agent
end
