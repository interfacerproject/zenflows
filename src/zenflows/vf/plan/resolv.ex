defmodule Zenflows.VF.Plan.Resolv do
@moduledoc "Resolvers of Plan."

use Absinthe.Schema.Notation

alias Zenflows.VF.{Plan, Plan.Domain}

def plan(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_plan(%{plan: params}, _info) do
	with {:ok, plan} <- Domain.create(params) do
		{:ok, %{plan: plan}}
	end
end

def update_plan(%{plan: %{id: id} = params}, _info) do
	with {:ok, plan} <- Domain.update(id, params) do
		{:ok, %{plan: plan}}
	end
end

def delete_plan(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def refinement_of(%Plan{} = plan, _args, _info) do
	plan = Domain.preload(plan, :refinement_of)
	{:ok, plan.refinement_of}
end
end
