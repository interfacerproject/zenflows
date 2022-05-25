defmodule Zenflows.VF.Agent.Domain do
@moduledoc "Domain logic of Agents."

alias Zenflows.DB.Repo
alias Zenflows.VF.Agent

@typep id() :: Zenflows.DB.Schema.id()

@spec by_id(id) :: Agent.t() | nil
def by_id(id) do
	Repo.get(Agent, id)
end

@spec preload(Agent.t(), :primary_location) :: Agent.t()
def preload(agent, :primary_location) do
	Repo.preload(agent, :primary_location)
end
end
