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

defmodule Zenflows.InstVars.Type do
@moduledoc "GraphQL types for instance-level, global variables."

use Absinthe.Schema.Notation

alias Zenflows.InstVars.Resolv

object :instance_units do
	field :unit_one, non_null(:unit), resolve: &Resolv.unit_one/3
	field :unit_currency, non_null(:unit), resolve: &Resolv.unit_currency/3
end

object :instance_specs do
	field :spec_project_design, non_null(:resource_specification),
		resolve: &Resolv.spec_project_design/3
	field :spec_project_service, non_null(:resource_specification),
		resolve: &Resolv.spec_project_service/3
	field :spec_project_product, non_null(:resource_specification),
		resolve: &Resolv.spec_project_product/3
end

object :instance_variables do
	field :units, non_null(:instance_units)
	field :specs, non_null(:instance_specs)
end

object :query_inst_vars do
	field :instance_variables, non_null(:instance_variables),
		resolve: &Resolv.instance_variables/2, meta: [only_guest?: true]
end
end
