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

defmodule Zenflows.VF.Agent.Domain do
@moduledoc "Domain logic of Agents."

alias Zenflows.DB.Repo
alias Zenflows.VF.Agent

@typep id() :: Zenflows.DB.Schema.id()

@spec by_id(id) :: Agent.t() | nil
def by_id(id) do
	Repo.get(Agent, id)
end

@spec preload(Agent.t(), :primary_location) :: Agent.t()
def preload(agent, :primary_location) do
	Repo.preload(agent, :primary_location)
end
end
