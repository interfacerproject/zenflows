defmodule Zenflows.Valflow.ResourceSpecification.Resolv do
@moduledoc "Resolvers of ResourceSpecifications."

alias Zenflows.Valflow.{
	ResourceSpecification,
	ResourceSpecification.Domain,
}

def resource_specification(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_resource_specification(%{resource_specification: params}, _info) do
	with {:ok, proc_spec} <- Domain.create(params) do
		{:ok, %{resource_specification: proc_spec}}
	end
end

def update_resource_specification(%{resource_specification: %{id: id} = params}, _info) do
	with {:ok, proc_spec} <- Domain.update(id, params) do
		{:ok, %{resource_specification: proc_spec}}
	end
end

def delete_resource_specification(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def default_unit_of_resource(%ResourceSpecification{} = res_spec, _args, _info) do
	res_spec = Domain.preload(res_spec, :default_unit_of_resource)
	{:ok, res_spec.default_unit_of_resource}
end

def default_unit_of_effort(%ResourceSpecification{} = res_spec, _args, _info) do
	res_spec = Domain.preload(res_spec, :default_unit_of_effort)
	{:ok, res_spec.default_unit_of_effort}
end
end
