# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.VF.EconomicResource.Resolv do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.GQL.Connection
alias Zenflows.VF.EconomicResource.Domain

def economic_resource(params, _) do
	Domain.one(params)
end

def economic_resources(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def economic_resource_classifications(_, _) do
	{:ok, Domain.classifications()}
end

def update_economic_resource(%{resource: %{id: id} = params}, _) do
	with {:ok, eco_res} <- Domain.update(id, params) do
		{:ok, %{economic_resource: eco_res}}
	end
end

def delete_economic_resource(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def images(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :images)
	{:ok, eco_res.images}
end

def conforms_to(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :conforms_to)
	{:ok, eco_res.conforms_to}
end

def accounting_quantity(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :accounting_quantity)
	{:ok, eco_res.accounting_quantity}
end

def onhand_quantity(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :onhand_quantity)
	{:ok, eco_res.onhand_quantity}
end

def primary_accountable(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :primary_accountable)
	{:ok, eco_res.primary_accountable}
end

def custodian(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :custodian)
	{:ok, eco_res.custodian}
end

def stage(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :stage)
	{:ok, eco_res.stage}
end

def state(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :state)
	{:ok, eco_res.state}
end

def current_location(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :current_location)
	{:ok, eco_res.current_location}
end

def lot(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :lot)
	{:ok, eco_res.lot}
end

def contained_in(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :contained_in)
	{:ok, eco_res.contained_in}
end

def unit_of_effort(eco_res, _, _) do
	eco_res = Domain.preload(eco_res, :unit_of_effort)
	{:ok, eco_res.unit_of_effort}
end

def previous(eco_res, _, _) do
	{:ok, Domain.previous(eco_res)}
end

def trace(eco_res, _, _) do
	{:ok, Domain.trace(eco_res)}
end

def trace_dpp_tree(eco_res, _, _) do
	{:ok, Domain.trace_dpp_tree(eco_res)}
end
end
