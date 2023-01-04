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

defmodule Zenflows.VF.Proposal.Resolv do
@moduledoc false

alias Zenflows.GQL.Connection
alias Zenflows.VF.Proposal.Domain

def proposal(params, _) do
	Domain.one(params)
end

def proposals(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def offers(_params, _) do
	{:ok, %{
		edges: [],
		page_info: %{
			has_previous_page: false,
			has_next_page: false,
		},
	}}
end

def requests(_params, _) do
	{:ok, %{
		edges: [],
		page_info: %{
			has_previous_page: false,
			has_next_page: false,
		},
	}}
end

def create_proposal(%{proposal: params}, _) do
	with {:ok, prop} <- Domain.create(params) do
		{:ok, %{proposal: prop}}
	end
end

def update_proposal(%{proposal: %{id: id} = params}, _) do
	with {:ok, prop} <- Domain.update(id, params) do
		{:ok, %{proposal: prop}}
	end
end

def delete_proposal(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def created(%{id: id}, _, _) do
	Zenflows.DB.ID.ts(id)
end

def eligible_location(prop, _, _) do
	prop = Domain.preload(prop, :eligible_location)
	{:ok, prop.eligible_location}
end

def publishes(prop, _, _) do
	prop = Domain.preload(prop, :publishes)
	{:ok, prop.publishes}
end

def primary_intents(prop, _, _) do
	prop = Domain.preload(prop, :primary_intents)
	{:ok, prop.primary_intents}
end

def reciprocal_intents(prop, _, _) do
	prop = Domain.preload(prop, :reciprocal_intents)
	{:ok, prop.reciprocal_intents}
end

def status(prop, _, _) do
	Domain.status(prop)
end
end
