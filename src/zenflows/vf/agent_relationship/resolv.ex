defmodule Zenflows.VF.AgentRelationship.Resolv do
@moduledoc "Resolvers of AgentRelationships."

alias Zenflows.VF.{AgentRelationship, AgentRelationship.Domain}

def subject(%AgentRelationship{} = rel, _params, _info) do
	rel = Domain.preload(rel, :subject)
	{:ok, rel.subject}
end

def object(%AgentRelationship{} = rel, _params, _info) do
	rel = Domain.preload(rel, :object)
	{:ok, rel.object}
end

def relationship(%AgentRelationship{} = rel, _params, _info) do
	rel = Domain.preload(rel, :relationship)
	{:ok, rel.relationship}
end

def agent_relationship(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_agent_relationship(%{relationship: params}, _info) do
	with {:ok, rel} <- Domain.create(params) do
		{:ok, %{agent_relationship: rel}}
	end
end

def update_agent_relationship(%{relationship: %{id: id} = params}, _info) do
	with {:ok, rel} <- Domain.update(id, params) do
		{:ok, %{agent_relationship: rel}}
	end
end

def delete_agent_relationship(%{id: id}, _info) do
	with {:ok, _rel} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
