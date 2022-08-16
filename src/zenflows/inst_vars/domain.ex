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

defmodule Zenflows.InstVars.Domain do
@moduledoc "Domain logict of instance-level, global variables."

use Agent

alias Zenflows.{DB.Repo, InstVars}
alias Zenflows.VF.{Unit, ResourceSpecification}

@doc false
def start_link(_) do
	[vars] = Repo.all(InstVars)
	Agent.start_link(fn -> %{
		units: %{
			unit_one: %{id: vars.unit_one_id},
			unit_currency: %{id: vars.unit_currency_id},
		},
		specs: %{
			spec_project_design: %{id: vars.spec_project_design_id},
			spec_project_service: %{id: vars.spec_project_service_id},
			spec_project_product: %{id: vars.spec_project_product_id},
		},
	} end, name: __MODULE__)
end

@spec get() :: %{units: [Unit.t()], specs: [ResourceSpecification.t()]}
def get() do
	Agent.get(__MODULE__, & &1)
end
end
