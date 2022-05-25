defmodule Zenflows.VF.ScenarioDefinition.Resolv do
@moduledoc "Resolvers of ScenarioDefinition."

use Absinthe.Schema.Notation

alias Zenflows.VF.{ScenarioDefinition, ScenarioDefinition.Domain}

def scenario_definition(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_scenario_definition(%{scenario_definition: params}, _info) do
	with {:ok, scen_def} <- Domain.create(params) do
		{:ok, %{scenario_definition: scen_def}}
	end
end

def update_scenario_definition(%{scenario_definition: %{id: id} = params}, _info) do
	with {:ok, scen_def} <- Domain.update(id, params) do
		{:ok, %{scenario_definition: scen_def}}
	end
end

def delete_scenario_definition(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def has_duration(%ScenarioDefinition{} = scen_def, _args, _info) do
	scen_def = Domain.preload(scen_def, :has_duration)
	{:ok, scen_def.has_duration}
end
end
