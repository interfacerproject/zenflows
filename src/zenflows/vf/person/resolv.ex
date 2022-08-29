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

alias Zenflows.VF.Person.Domain

def person(params, _) do
	Domain.one(params)
end

def people(params, _) do
	Domain.all(params)
end

def person_exists(params, _) do
	Domain.one(params)
end

def create_person(%{person: params}, _) do
	with {:ok, per} <- Domain.create(params) do
		{:ok, %{agent: per}}
	end
end

def update_person(%{person: %{id: id} = params}, _) do
	with {:ok, per} <- Domain.update(id, params) do
		{:ok, %{agent: per}}
	end
end

def delete_person(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def images(per, _, _) do
	per = Domain.preload(per, :images)
	{:ok, per.images}
end

def primary_location(per, _, _) do
	per = Domain.preload(per, :primary_location)
	{:ok, per.primary_location}
end
end
