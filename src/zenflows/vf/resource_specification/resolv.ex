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

defmodule Zenflows.VF.ResourceSpecification.Resolv do
@moduledoc false

alias Zenflows.GQL.Connection
alias Zenflows.VF.ResourceSpecification.Domain

def resource_specification(params, _) do
	Domain.one(params)
end

def resource_specifications(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def create_resource_specification(%{resource_specification: params}, _) do
	with {:ok, proc_spec} <- Domain.create(params) do
		{:ok, %{resource_specification: proc_spec}}
	end
end

def update_resource_specification(%{resource_specification: %{id: id} = params}, _) do
	with {:ok, proc_spec} <- Domain.update(id, params) do
		{:ok, %{resource_specification: proc_spec}}
	end
end

def delete_resource_specification(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def images(res_spec, _, _) do
	res_spec = Domain.preload(res_spec, :images)
	{:ok, res_spec.images}
end

def default_unit_of_resource(res_spec, _, _) do
	res_spec = Domain.preload(res_spec, :default_unit_of_resource)
	{:ok, res_spec.default_unit_of_resource}
end

def default_unit_of_effort(res_spec, _, _) do
	res_spec = Domain.preload(res_spec, :default_unit_of_effort)
	{:ok, res_spec.default_unit_of_effort}
end
end
