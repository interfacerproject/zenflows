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

alias Zenflows.DB.{Paging, Repo}
alias Zenflows.VF.Agent

@typep repo() :: Ecto.Repo.t()
@typep id() :: Zenflows.DB.Schema.id()

@spec one(repo(), id() | map() | Keyword.t()) :: {:ok, Agent.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(Agent, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec all(Paging.params()) :: Paging.result()
def all(params) do
	Paging.page(Agent, params)
end

@spec preload(Agent.t(), :primary_location) :: Agent.t()
def preload(agent, :primary_location) do
	Repo.preload(agent, :primary_location)
end
end
