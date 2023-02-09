# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.Intent.Resolv do
@moduledoc false

alias Zenflows.GQL.Connection
alias Zenflows.VF.Intent.Domain

def intent(params, _) do
	Domain.one(params)
end

def intents(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_intent(%{intent: params}, _) do
	with {:ok, int} <- Domain.create(params) do
		{:ok, %{intent: int}}
	end
end

def update_intent(%{intent: %{id: id} = params}, _) do
	with {:ok, int} <- Domain.update(id, params) do
		{:ok, %{intent: int}}
	end
end

def delete_intent(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def action(int, _, _) do
	int = Domain.preload(int, :action)
	{:ok, int.action}
end

def input_of(int, _, _) do
	int = Domain.preload(int, :input_of)
	{:ok, int.input_of}
end

def output_of(int, _, _) do
	int = Domain.preload(int, :output_of)
	{:ok, int.output_of}
end

def provider(int, _, _) do
	int = Domain.preload(int, :provider)
	{:ok, int.provider}
end

def receiver(int, _, _) do
	int = Domain.preload(int, :receiver)
	{:ok, int.receiver}
end

def resource_inventoried_as(int, _, _) do
	int = Domain.preload(int, :resource_inventoried_as)
	{:ok, int.resource_inventoried_as}
end

def resource_conforms_to(int, _, _) do
	int = Domain.preload(int, :resource_conforms_to)
	{:ok, int.resource_conforms_to}
end

def resource_quantity(int, _, _) do
	int = Domain.preload(int, :resource_quantity)
	{:ok, int.resource_quantity}
end

def effort_quantity(int, _, _) do
	int = Domain.preload(int, :effort_quantity)
	{:ok, int.effort_quantity}
end

def available_quantity(int, _, _) do
	int = Domain.preload(int, :available_quantity)
	{:ok, int.available_quantity}
end

def at_location(int, _, _) do
	int = Domain.preload(int, :at_location)
	{:ok, int.at_location}
end

def published_in(int, _, _) do
	int = Domain.preload(int, :published_in)
	{:ok, int.published_in}
end
end
