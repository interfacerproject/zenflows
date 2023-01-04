# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.EconomicEvent.Resolv do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.GQL.Connection
alias Zenflows.VF.EconomicEvent.Domain

def economic_event(params, _) do
	Domain.one(params)
end

def economic_events(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_economic_event(%{event: evt_params} = params, _) do
	res_params = params[:new_inventoried_resource]
	with {:ok, evt} <- Domain.create(evt_params, res_params) do
		{:ok, %{economic_event: evt}}
	end
end

def update_economic_event(%{economic_event: %{id: id} = params}, _) do
	with {:ok, eco_evt} <- Domain.update(id, params) do
		{:ok, %{economic_event: eco_evt}}
	end
end

def action(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :action)
	{:ok, eco_evt.action}
end

def input_of(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :input_of)
	{:ok, eco_evt.input_of}
end

def output_of(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :output_of)
	{:ok, eco_evt.output_of}
end

def provider(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :provider)
	{:ok, eco_evt.provider}
end

def receiver(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :receiver)
	{:ok, eco_evt.receiver}
end

def resource_inventoried_as(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :resource_inventoried_as)
	{:ok, eco_evt.resource_inventoried_as}
end

def to_resource_inventoried_as(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :to_resource_inventoried_as)
	{:ok, eco_evt.to_resource_inventoried_as}
end

def resource_quantity(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :resource_quantity)
	{:ok, eco_evt.resource_quantity}
end

def effort_quantity(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :effort_quantity)
	{:ok, eco_evt.effort_quantity}
end

def resource_conforms_to(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :resource_conforms_to)
	{:ok, eco_evt.resource_conforms_to}
end

def to_location(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :to_location)
	{:ok, eco_evt.to_location}
end

def at_location(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :at_location)
	{:ok, eco_evt.at_location}
end

def realization_of(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :realization_of)
	{:ok, eco_evt.realization_of}
end

def triggered_by(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :triggered_by)
	{:ok, eco_evt.triggered_by}
end

def previous_event(eco_evt, _, _) do
	eco_evt = Domain.preload(eco_evt, :previous_event)
	{:ok, eco_evt.previous_event}
end

def previous(eco_evt, _, _) do
	{:ok, Domain.previous(eco_evt)}
end
end
