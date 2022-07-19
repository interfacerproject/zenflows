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

alias Zenflows.VF.{Agent, Agent.Domain}

def my_agent(_args, _info) do
	agent = %Agent{
		type: :per,
		id: Zenflows.DB.ID.gen(),
		name: "hello",
		image: "https://example.test/img.jpg",
		note: "world",
	}
	{:ok, agent}
end

def agent(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def primary_location(%Agent{} = agent, _args, _info) do
	agent = Domain.preload(agent, :primary_location)
	{:ok, agent.primary_location}
end
end
