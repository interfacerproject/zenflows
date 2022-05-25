defmodule Zenflows.VF.SpatialThing.Resolv do
@moduledoc "Resolvers of SpatialThings."
# Basically, a fancy name for (geo)location.  :P

alias Zenflows.VF.SpatialThing.Domain

def spatial_thing(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_spatial_thing(%{spatial_thing: params}, _info) do
	with {:ok, spt_thg} <- Domain.create(params) do
		{:ok, %{spatial_thing: spt_thg}}
	end
end

def update_spatial_thing(%{spatial_thing: %{id: id} = params}, _info) do
	with {:ok, spt_thg} <- Domain.update(id, params) do
		{:ok, %{spatial_thing: spt_thg}}
	end
end

def delete_spatial_thing(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
