defmodule Zenflows.VF.ProcessSpecification.Resolv do
@moduledoc "Resolvers of ProcessSpecifications."

alias Zenflows.VF.ProcessSpecification.Domain

def process_specification(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_process_specification(%{process_specification: params}, _info) do
	with {:ok, proc_spec} <- Domain.create(params) do
		{:ok, %{process_specification: proc_spec}}
	end
end

def update_process_specification(%{process_specification: %{id: id} = params}, _info) do
	with {:ok, proc_spec} <- Domain.update(id, params) do
		{:ok, %{process_specification: proc_spec}}
	end
end

def delete_process_specification(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
