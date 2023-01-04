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

defmodule Zenflows.VF.RecipeProcess.Resolv do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.GQL.Connection
alias Zenflows.VF.RecipeProcess.Domain

def recipe_process(params, _) do
	Domain.one(params)
end

def recipe_processes(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_recipe_process(%{recipe_process: params}, _) do
	with {:ok, rec_proc} <- Domain.create(params) do
		{:ok, %{recipe_process: rec_proc}}
	end
end

def update_recipe_process(%{recipe_process: %{id: id} = params}, _) do
	with {:ok, rec_proc} <- Domain.update(id, params) do
		{:ok, %{recipe_process: rec_proc}}
	end
end

def delete_recipe_process(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def has_duration(rec_proc, _, _) do
	rec_proc = Domain.preload(rec_proc, :has_duration)
	{:ok, rec_proc.has_duration}
end

def process_conforms_to(rec_proc, _, _) do
	rec_proc = Domain.preload(rec_proc, :process_conforms_to)
	{:ok, rec_proc.process_conforms_to}
end
end
