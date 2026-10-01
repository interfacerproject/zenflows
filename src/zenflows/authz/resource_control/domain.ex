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

defmodule Zenflows.Authz.ResourceControl.Domain do
@moduledoc "Reads of resource control, and its creation with each new resource."

alias Ecto.Multi
alias Zenflows.Authz.{ExecutionContext, Facts, Log, ResourceControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.{EconomicResource, Person}

@spec one(Ecto.Repo.t(), String.t()) :: {:ok, ResourceControl.t()} | {:error, String.t()}
def one(repo \\ Repo, resource_id) do
	case repo.get_by(ResourceControl, resource_id: resource_id) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@doc """
Insert the control row (and its log entry) for the resource stored
under `res_key`.  Migration contexts are skipped: the backfill
migration covers resources created by earlier migrations.
"""
@spec multi_on_create(Multi.t(), ExecutionContext.t(), term()) :: Multi.t()
def multi_on_create(m, %ExecutionContext{principal: {:service, :migration, _}}, _res_key), do: m
def multi_on_create(m, ctx, res_key) do
	m
	|> Multi.run("#{res_key}.control", fn repo, changes ->
		%EconomicResource{} = res = Map.fetch!(changes, res_key)
		{controller_id, source} = controller_for(repo, ctx, res)
		%{resource_id: res.id, controller_id: controller_id, source: source}
		|> ResourceControl.changeset()
		|> repo.insert()
	end)
	|> Log.multi_insert("#{res_key}.control.log", ctx, fn changes ->
		control = Map.fetch!(changes, "#{res_key}.control")
		res = Map.fetch!(changes, res_key)
		%{
			action: "resource_control.set",
			target_type: "economic_resource",
			target_id: control.resource_id,
			subject_id: control.controller_id,
			after: %{
				controller_id: control.controller_id,
				source: control.source,
				declared_receiver_id: res.primary_accountable_id,
			},
		}
	end)
end

@doc """
Who controls a new resource: the verified creator, or the receiving
organization when the creator is its admin.  Never the declared
receiver alone (events are not authorized yet).
"""
@spec controller_for(Ecto.Repo.t(), ExecutionContext.t(), EconomicResource.t())
	:: {String.t(), ResourceControl.source()}
def controller_for(repo, %ExecutionContext{principal: %Person{id: pid}} = ctx, res) do
	receiver = res.primary_accountable_id
	cond do
		receiver == pid -> {pid, :creation}
		MapSet.member?(Facts.admin_of(repo, ctx), receiver) -> {receiver, :creation}
		true -> {pid, :creation}
	end
end
def controller_for(_repo, %ExecutionContext{principal: {:service, :import, _}}, res),
	do: {res.primary_accountable_id, :admin}
def controller_for(_repo, _ctx, res),
	do: {res.primary_accountable_id, :creation}
end
