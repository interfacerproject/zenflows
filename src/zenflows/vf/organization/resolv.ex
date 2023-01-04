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

defmodule Zenflows.VF.Organization.Resolv do
@moduledoc false

alias Zenflows.GQL.Connection
alias Zenflows.VF.Organization.Domain

def organization(params, _) do
	Domain.one(params)
end

def organizations(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_organization(%{organization: params}, _) do
	with {:ok, org} <- Domain.create(params) do
		{:ok, %{agent: org}}
	end
end

def update_organization(%{organization: %{id: id} = params}, _) do
	with {:ok, org} <- Domain.update(id, params) do
		{:ok, %{agent: org}}
	end
end

def delete_organization(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def images(org, _, _) do
	org = Domain.preload(org, :images)
	{:ok, org.images}
end

def primary_location(org, _, _) do
	org = Domain.preload(org, :primary_location)
	{:ok, org.primary_location}
end
end
