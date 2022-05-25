defmodule Zenflows.VF.EconomicEvent.Resolv do
@moduledoc "Resolvers of EconomicEvent."

use Absinthe.Schema.Notation

alias Zenflows.VF.{
	EconomicEvent,
	EconomicEvent.Domain,
}

def economic_event(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_economic_event(%{event: evt_params} = params, _info) do
	res_params = params[:new_inventoried_resource]
	case Domain.create(evt_params, res_params) do
		{:ok, evt, res, nil} ->
			evt = Map.put(evt, :resource_inventoried_as, res) # tiny optimization
			{:ok, %{economic_event: evt}}

		{:ok, evt, nil, to_res} ->
			evt = Map.put(evt, :to_resource_inventoried_as, to_res) # tiny optimization
			{:ok, %{economic_event: evt}}

		{:ok, evt} ->
			{:ok, %{economic_event: evt}}

		{:error, err} ->
			{:error, err}
	end
end

def update_economic_event(%{economic_event: %{id: id} = params}, _info) do
	with {:ok, eco_evt} <- Domain.update(id, params) do
		{:ok, %{economic_event: eco_evt}}
	end
end

def action(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :action)
	{:ok, eco_evt.action}
end

def input_of(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :input_of)
	{:ok, eco_evt.input_of}
end

def output_of(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :output_of)
	{:ok, eco_evt.output_of}
end

def provider(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :provider)
	{:ok, eco_evt.provider}
end

def receiver(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :receiver)
	{:ok, eco_evt.receiver}
end

def resource_inventoried_as(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :resource_inventoried_as)
	{:ok, eco_evt.resource_inventoried_as}
end

def to_resource_inventoried_as(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :to_resource_inventoried_as)
	{:ok, eco_evt.to_resource_inventoried_as}
end

def resource_quantity(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :resource_quantity)
	{:ok, eco_evt.resource_quantity}
end

def effort_quantity(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :effort_quantity)
	{:ok, eco_evt.effort_quantity}
end

def resource_conforms_to(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :resource_conforms_to)
	{:ok, eco_evt.resource_conforms_to}
end

def to_location(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :to_location)
	{:ok, eco_evt.to_location}
end

def at_location(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :at_location)
	{:ok, eco_evt.at_location}
end

def realization_of(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :realization_of)
	{:ok, eco_evt.realization_of}
end

def triggered_by(%EconomicEvent{} = eco_evt, _args, _info) do
	eco_evt = Domain.preload(eco_evt, :triggered_by)
	{:ok, eco_evt.triggered_by}
end
end
