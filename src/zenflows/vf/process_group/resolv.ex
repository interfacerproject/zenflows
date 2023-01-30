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

defmodule Zenflows.VF.ProcessGroup.Resolv do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.GQL.Connection
alias Zenflows.VF.ProcessGroup.Domain

def process_group(params, _) do
	Domain.one(params)
end

def process_groups(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_process_group(%{process_group: params}, _) do
	with {:ok, procgrp} <- Domain.create(params) do
		{:ok, %{process_group: procgrp}}
	end
end

def update_process_group(%{process_group: %{id: id} = params}, _) do
	with {:ok, procgrp} <- Domain.update(id, params) do
		{:ok, %{process_group: procgrp}}
	end
end

def delete_process_group(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def groups(procgrp, params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.groups(procgrp.id, page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def grouped_in(procgrp, _, _) do
	procgrp = Domain.preload(procgrp, :grouped_in)
	{:ok, procgrp.grouped_in}
end
end
