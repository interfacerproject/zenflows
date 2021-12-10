defmodule Zenflows.Valflow.Agent.Domain do
@moduledoc "Domain logic of Agents."

alias Zenflows.Ecto.Repo
alias Zenflows.Valflow.Agent

@typep id() :: Zenflows.Ecto.Schema.id()

@spec by_id(id) :: Agent.t() | nil
def by_id(id) do
	Repo.get(Agent, id)
end

@spec preload(Agent.t(), :primary_location) :: Agent.t()
def preload(agent, :primary_location) do
	Repo.preload(agent, :primary_location)
end
end
