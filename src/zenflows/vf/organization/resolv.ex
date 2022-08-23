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

defmodule Zenflows.VF.Organization.Resolv do
@moduledoc "Resolvers of Organizations."

alias Zenflows.VF.{Agent, Organization, Organization.Domain}

def organization(params, _) do
	Domain.one(params)
end

def organizations(params, _) do
	Domain.all(params)
end

def create_organization(%{organization: params}, _) do
	with {:ok, org} <- Domain.create(params) do
		{:ok, %{agent: org}}
	end
end

def update_organization(%{organization: %{id: id} = params}, _) do
	with {:ok, org} <- Domain.update(id, params) do
		{:ok, %{agent: org}}
	end
end

def delete_organization(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def primary_location(%Organization{} = org, _, _) do
	org = Domain.preload(org, :primary_location)
	{:ok, org.primary_location}
end

# For some reason, Absinthe calls this one instead of the one on
# Zenflows.VF.Agent.Type for queries to Agent itself.
def primary_location(%Agent{} = agent, params, info) do
	Agent.Resolv.primary_location(agent, params, info)
end
end
