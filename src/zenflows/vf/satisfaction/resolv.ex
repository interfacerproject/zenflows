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

defmodule Zenflows.VF.Satisfaction.Resolv do
@moduledoc false

alias Zenflows.GQL.Connection
alias Zenflows.VF.Satisfaction.Domain

def satisfaction(params, _) do
	Domain.one(params)
end

def satisfactions(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_satisfaction(%{satisfaction: params}, _) do
	with {:ok, satis} <- Domain.create(params) do
		{:ok, %{satisfaction: satis}}
	end
end

def update_satisfaction(%{satisfaction: %{id: id} = params}, _) do
	with {:ok, satis} <- Domain.update(id, params) do
		{:ok, %{satisfaction: satis}}
	end
end

def delete_satisfaction(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def satisfies(satis, _, _) do
	satis = Domain.preload(satis, :satisfies)
	{:ok, satis.satisfies}
end

def satisfied_by_event(satis, _, _) do
	satis = Domain.preload(satis, :satisfied_by_event)
	{:ok, satis.satisfied_by_event}
end

def satisfied_by_commitment(satis, _, _) do
	satis = Domain.preload(satis, :satisfied_by_commitment)
	{:ok, satis.satisfied_by_commitment}
end

def resource_quantity(satis, _, _) do
	satis = Domain.preload(satis, :resource_quantity)
	{:ok, satis.resource_quantity}
end

def effort_quantity(satis, _, _) do
	satis = Domain.preload(satis, :effort_quantity)
	{:ok, satis.effort_quantity}
end
end
