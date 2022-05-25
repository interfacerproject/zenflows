defmodule Zenflows.VF.Unit.Resolv do
@moduledoc "Resolvers of Units."

alias Zenflows.VF.Unit.Domain

def unit(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_unit(%{unit: params}, _info) do
	with {:ok, unit} <- Domain.create(params) do
		{:ok, %{unit: unit}}
	end
end

def update_unit(%{unit: %{id: id} = params}, _info) do
	with {:ok, unit} <- Domain.update(id, params) do
		{:ok, %{unit: unit}}
	end
end

def delete_unit(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
