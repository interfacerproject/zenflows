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

defmodule Zenflows.VF.Agent.Resolv do
@moduledoc false

alias Zenflows.GQL.Connection
alias Zenflows.VF.Agent.Domain

def my_agent(_, %{context: %{req_user: user}}) do
	{:ok, user}
end

def agent(params, _) do
	Domain.one(params)
end

def agents(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
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
