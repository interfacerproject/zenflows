defmodule Zenflows.VF.Scenario.Resolv do
@moduledoc "Resolvers of Scenario."

use Absinthe.Schema.Notation

alias Zenflows.VF.{Scenario, Scenario.Domain}

def scenario(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_scenario(%{scenario: params}, _info) do
	with {:ok, scen} <- Domain.create(params) do
		{:ok, %{scenario: scen}}
	end
end

def update_scenario(%{scenario: %{id: id} = params}, _info) do
	with {:ok, scen} <- Domain.update(id, params) do
		{:ok, %{scenario: scen}}
	end
end

def delete_scenario(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def defined_as(%Scenario{} = scen, _args, _info) do
	scenario = Domain.preload(scen, :defined_as)
	{:ok, scenario.defined_as}
end

def refinement_of(%Scenario{} = scen, _args, _info) do
	scenario = Domain.preload(scen, :refinement_of)
	{:ok, scenario.refinement_of}
end
end
