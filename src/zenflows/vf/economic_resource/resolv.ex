defmodule Zenflows.VF.EconomicResource.Resolv do
@moduledoc "Resolvers of EconomicResource."

use Absinthe.Schema.Notation

alias Zenflows.VF.{
	EconomicResource,
	EconomicResource.Domain,
}

def economic_resource(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def update_economic_resource(%{resource: %{id: id} = params}, _info) do
	with {:ok, eco_res} <- Domain.update(id, params) do
		{:ok, %{economic_resource: eco_res}}
	end
end

def delete_economic_resource(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def conforms_to(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :conforms_to)
	{:ok, eco_res.conforms_to}
end

def accounting_quantity(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :accounting_quantity)
	{:ok, eco_res.accounting_quantity}
end

def onhand_quantity(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :onhand_quantity)
	{:ok, eco_res.onhand_quantity}
end

def primary_accountable(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :primary_accountable)
	{:ok, eco_res.primary_accountable}
end

def custodian(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :custodian)
	{:ok, eco_res.custodian}
end

def stage(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :stage)
	{:ok, eco_res.stage}
end

def state(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :state)
	{:ok, eco_res.state}
end

def current_location(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :current_location)
	{:ok, eco_res.current_location}
end

def lot(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :lot)
	{:ok, eco_res.lot}
end

def contained_in(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :contained_in)
	{:ok, eco_res.contained_in}
end

def unit_of_effort(%EconomicResource{} = eco_res, _args, _info) do
	eco_res = Domain.preload(eco_res, :unit_of_effort)
	{:ok, eco_res.unit_of_effort}
end
end
