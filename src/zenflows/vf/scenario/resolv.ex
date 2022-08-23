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

defmodule Zenflows.VF.Scenario.Resolv do
@moduledoc "Resolvers of Scenario."

use Absinthe.Schema.Notation

alias Zenflows.VF.Scenario.Domain

def scenario(params, _) do
	Domain.one(params)
end

def scenarios(params, _) do
	Domain.all(params)
end

def create_scenario(%{scenario: params}, _) do
	with {:ok, scen} <- Domain.create(params) do
		{:ok, %{scenario: scen}}
	end
end

def update_scenario(%{scenario: %{id: id} = params}, _) do
	with {:ok, scen} <- Domain.update(id, params) do
		{:ok, %{scenario: scen}}
	end
end

def delete_scenario(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def defined_as(scen, _, _) do
	scenario = Domain.preload(scen, :defined_as)
	{:ok, scenario.defined_as}
end

def refinement_of(scen, _, _) do
	scenario = Domain.preload(scen, :refinement_of)
	{:ok, scenario.refinement_of}
end
end
