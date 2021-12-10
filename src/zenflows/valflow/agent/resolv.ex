defmodule Zenflows.Valflow.Agent.Resolv do
@moduledoc "Resolvers of Agents."

alias Zenflows.Valflow.{Agent, Agent.Domain}

def my_agent(_args, _info) do
	agent = %Agent{
		type: :per,
		id: Zenflows.Ecto.Id.gen(),
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
