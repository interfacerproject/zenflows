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

defmodule Zenflows.VF.ScenarioDefinition.Resolv do
@moduledoc "Resolvers of ScenarioDefinition."

use Absinthe.Schema.Notation

alias Zenflows.VF.{ScenarioDefinition, ScenarioDefinition.Domain}

def scenario_definition(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_scenario_definition(%{scenario_definition: params}, _info) do
	with {:ok, scen_def} <- Domain.create(params) do
		{:ok, %{scenario_definition: scen_def}}
	end
end

def update_scenario_definition(%{scenario_definition: %{id: id} = params}, _info) do
	with {:ok, scen_def} <- Domain.update(id, params) do
		{:ok, %{scenario_definition: scen_def}}
	end
end

def delete_scenario_definition(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def has_duration(%ScenarioDefinition{} = scen_def, _args, _info) do
	scen_def = Domain.preload(scen_def, :has_duration)
	{:ok, scen_def.has_duration}
end
end
