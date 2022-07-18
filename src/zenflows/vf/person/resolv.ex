defmodule Zenflows.VF.Person.Resolv do
@moduledoc "Resolvers of Persons."

alias Zenflows.VF.{Agent, Person, Person.Domain}

def person(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_person(%{person: params}, _info) do
	with {:ok, per} <- Domain.create(params) do
		{:ok, %{agent: per}}
	end
end

def update_person(%{person: %{id: id} = params}, _info) do
	with {:ok, per} <- Domain.update(id, params) do
		{:ok, %{agent: per}}
	end
end

def delete_person(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def primary_location(%Person{} = per, _args, _info) do
	per = Domain.preload(per, :primary_location)
	{:ok, per.primary_location}
end

# For some reason, Absinthe calls this one instead of the one on
# Zenflows.VF.Agent.Type for queries to Agent itself.
def primary_location(%Agent{} = agent, args, info) do
	Agent.Resolv.primary_location(agent, args, info)
end

def pubkeys(%Person{} = per, _args, _info) do
	{:ok, Base.url_encode64(per.pubkeys)}
end
end
