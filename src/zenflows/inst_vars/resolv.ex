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

defmodule Zenflows.InstVars.Resolv do
@moduledoc "Resolvers of instance-level, global variables."

alias Zenflows.InstVars.Domain
alias Zenflows.VF.{Unit, ResourceSpecification}

def instance_variables(_, _) do
	{:ok, Domain.get()}
end

def unit_one(%{unit_one: %{id: id}}, _, _) do
	Unit.Domain.one(id)
end

def unit_currency(%{unit_currency: %{id: id}}, _, _) do
	Unit.Domain.one(id)
end

def spec_project_design(%{spec_project_design: %{id: id}}, _, _) do
	ResourceSpecification.Domain.one(id)
end

def spec_project_service(%{spec_project_service: %{id: id}}, _, _) do
	ResourceSpecification.Domain.one(id)
end

def spec_project_product(%{spec_project_product: %{id: id}}, _, _) do
	ResourceSpecification.Domain.one(id)
end
end
