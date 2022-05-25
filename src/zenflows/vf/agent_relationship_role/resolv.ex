defmodule Zenflows.VF.AgentRelationshipRole.Resolv do
@moduledoc "Resolvers of AgentRelationshipRoles."

alias Zenflows.VF.{AgentRelationshipRole, AgentRelationshipRole.Domain}

def role_behavior(%AgentRelationshipRole{} = rel_role, _args, _info) do
	rel_role = Domain.preload(rel_role, :role_behavior)
	{:ok, rel_role.role_behavior}
end

def agent_relationship_role(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_agent_relationship_role(%{agent_relationship_role: params}, _info) do
	with {:ok, rel_role} <- Domain.create(params) do
		{:ok, %{agent_relationship_role: rel_role}}
	end
end

def update_agent_relationship_role(%{agent_relationship_role: %{id: id} = params}, _info) do
	with {:ok, rel_role} <- Domain.update(id, params) do
		{:ok, %{agent_relationship_role: rel_role}}
	end
end

def delete_agent_relationship_role(%{id: id}, _info) do
	with {:ok, _rel_role} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
