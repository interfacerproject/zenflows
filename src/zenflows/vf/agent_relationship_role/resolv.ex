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

defmodule Zenflows.VF.AgentRelationshipRole.Resolv do
@moduledoc false

alias Zenflows.GQL.Connection
alias Zenflows.VF.{AgentRelationshipRole, AgentRelationshipRole.Domain}

def agent_relationship_role(params, _) do
	Domain.one(params)
end

def agent_relationship_roles(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_agent_relationship_role(%{agent_relationship_role: params}, _) do
	with {:ok, rel_role} <- Domain.create(params) do
		{:ok, %{agent_relationship_role: rel_role}}
	end
end

def update_agent_relationship_role(%{agent_relationship_role: %{id: id} = params}, _) do
	with {:ok, rel_role} <- Domain.update(id, params) do
		{:ok, %{agent_relationship_role: rel_role}}
	end
end

def delete_agent_relationship_role(%{id: id}, _) do
	with {:ok, _rel_role} <- Domain.delete(id) do
		{:ok, true}
	end
end

def role_behavior(%AgentRelationshipRole{} = rel_role, _, _) do
	rel_role = Domain.preload(rel_role, :role_behavior)
	{:ok, rel_role.role_behavior}
end

end
