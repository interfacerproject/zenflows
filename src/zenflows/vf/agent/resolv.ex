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

defmodule Zenflows.VF.Agent.Resolv do
@moduledoc "Resolvers of Agents."

alias Zenflows.VF.Agent.Domain

def my_agent(_, %{context: %{req_user: user}}) do
	{:ok, user}
end

def agent(params, _) do
	Domain.one(params)
end

def agents(params, _) do
	Domain.all(params)
end

def images(agent, _, _) do
	agent = Domain.preload(agent, :images)
	{:ok, agent.images}
end

def primary_location(agent, _, _) do
	agent = Domain.preload(agent, :primary_location)
	{:ok, agent.primary_location}
end
end
