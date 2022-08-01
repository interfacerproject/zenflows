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

defmodule Zenflows.VF.Person.Resolv do
@moduledoc "Resolvers of Persons."

alias Zenflows.VF.{Agent, Person, Person.Domain}

def person(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def person_exists(params, _info) do
	{:ok, Domain.by(params)}
end

def create_person(%{person: params}, _info) do
	with {:ok, per} <- Domain.create(params) do
		{:ok, %{agent: per}}
	end
end

def update_person(%{person: %{id: id} = params}, _info) do
	with {:ok, per} <- Domain.update(id, params) do
		{:ok, %{agent: per}}
	end
end

def delete_person(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def primary_location(%Person{} = per, _args, _info) do
	per = Domain.preload(per, :primary_location)
	{:ok, per.primary_location}
end

# For some reason, Absinthe calls this one instead of the one on
# Zenflows.VF.Agent.Type for queries to Agent itself.
def primary_location(%Agent{} = agent, args, info) do
	Agent.Resolv.primary_location(agent, args, info)
end
end
