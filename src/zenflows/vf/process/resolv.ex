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

defmodule Zenflows.VF.Process.Resolv do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.GQL.Connection
alias Zenflows.VF.Process.Domain

def process(params, _) do
	Domain.one(params)
end

def processes(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_process(%{process: params}, _) do
	with {:ok, process} <- Domain.create(params) do
		{:ok, %{process: process}}
	end
end

def update_process(%{process: %{id: id} = params}, _) do
	with {:ok, proc} <- Domain.update(id, params) do
		{:ok, %{process: proc}}
	end
end

def delete_process(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def based_on(proc, _, _) do
	proc = Domain.preload(proc, :based_on)
	{:ok, proc.based_on}
end

def planned_within(proc, _, _) do
	proc = Domain.preload(proc, :planned_within)
	{:ok, proc.planned_within}
end

def nested_in(proc, _, _) do
	proc = Domain.preload(proc, :nested_in)
	{:ok, proc.nested_in}
end

def previous(proc, _, _) do
	{:ok, Domain.previous(proc)}
end

def grouped_in(proc, _, _) do
	proc = Domain.preload(proc, :grouped_in)
	{:ok, proc.grouped_in}
end
end
