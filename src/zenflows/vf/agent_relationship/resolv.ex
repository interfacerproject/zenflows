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

defmodule Zenflows.VF.AgentRelationship.Resolv do
@moduledoc false

alias Zenflows.GQL.Connection
alias Zenflows.VF.{AgentRelationship, AgentRelationship.Domain}

def agent_relationship(params, _) do
	Domain.one(params)
end

def agent_relationships(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_agent_relationship(%{relationship: params}, _) do
	with {:ok, rel} <- Domain.create(params) do
		{:ok, %{agent_relationship: rel}}
	end
end

def update_agent_relationship(%{relationship: %{id: id} = params}, _) do
	with {:ok, rel} <- Domain.update(id, params) do
		{:ok, %{agent_relationship: rel}}
	end
end

def delete_agent_relationship(%{id: id}, _) do
	with {:ok, _rel} <- Domain.delete(id) do
		{:ok, true}
	end
end

def subject(%AgentRelationship{} = rel, _, _) do
	rel = Domain.preload(rel, :subject)
	{:ok, rel.subject}
end

def object(%AgentRelationship{} = rel, _, _) do
	rel = Domain.preload(rel, :object)
	{:ok, rel.object}
end

def relationship(%AgentRelationship{} = rel, _, _) do
	rel = Domain.preload(rel, :relationship)
	{:ok, rel.relationship}
end

end
