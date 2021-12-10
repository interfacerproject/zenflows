defmodule Zenflows.Valflow.Organization.Resolv do
@moduledoc "Resolvers of Organizations."

alias Zenflows.Valflow.{Agent, Organization, Organization.Domain}

def organization(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_organization(%{organization: params}, _info) do
	with {:ok, org} <- Domain.create(params) do
		{:ok, %{agent: org}}
	end
end

def update_organization(%{organization: %{id: id} = params}, _info) do
	with {:ok, org} <- Domain.update(id, params) do
		{:ok, %{agent: org}}
	end
end

def delete_organization(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def primary_location(%Organization{} = org, _args, _info) do
	org = Domain.preload(org, :primary_location)
	{:ok, org.primary_location}
end

# For some reason, Absinthe calls this one instead of the one on
# Zenflows.Valflow.Agent.Type for queries to Agent itself.
def primary_location(%Agent{} = agent, args, info) do
	Agent.Resolv.primary_location(agent, args, info)
end
end
