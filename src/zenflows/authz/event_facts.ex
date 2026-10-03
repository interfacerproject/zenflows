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

defmodule Zenflows.Authz.EventFacts do
@moduledoc """
Everything an event decision may look at.  `EconomicEvent.Domain`
loads it with row locks before the event is written.
"""

import Ecto.Query

alias Zenflows.Authz.{Config, EventPolicy, ExecutionContext, Facts, ObjectControl, ResourceControl}
alias Zenflows.VF.{EconomicEvent, EconomicResource}

@type t() :: %__MODULE__{
	action: nil | String.t(),
	provider_id: nil | String.t(),
	receiver_id: nil | String.t(),
	source_id: nil | String.t(),
	event: nil | struct(),
	touched: Zenflows.Authz.EventPolicy.touched(),
	resources: %{String.t() => struct()},
	controls: %{String.t() => ResourceControl.t()},
	contained: %{String.t() => [String.t()]},
	process_ids: [String.t()],
	process_controls: %{String.t() => ObjectControl.t()},
	admin_of: MapSet.t(String.t()),
	claimable: MapSet.t(String.t()),
}

defstruct action: nil,
	provider_id: nil,
	receiver_id: nil,
	source_id: nil,
	event: nil,
	touched: %{changes: [], references: [], creates: :none},
	resources: %{},
	controls: %{},
	contained: %{},
	process_ids: [],
	process_controls: %{},
	admin_of: MapSet.new(),
	claimable: MapSet.new()

@doc """
Facts for `event.create`.  Locks, in this order: touched resources and
the resources contained in changed ones (one query, ascending id,
FOR UPDATE), their control rows (ascending, FOR UPDATE), the process
control rows of `input_of`/`output_of` (one query, ascending by
target_id, FOR SHARE), then the admin rows the decision needs
(FOR SHARE).
"""
@spec load(Ecto.Repo.t(), ExecutionContext.t(), map()) :: t()
def load(repo, ctx, changes) do
	touched = EventPolicy.touched(changes)
	contained = contained_of(repo, touched.changes)
	inner = contained |> Map.values() |> List.flatten()

	resources =
		lock_resources(repo, Enum.uniq(touched.changes ++ touched.references ++ inner))
	controls = lock_controls(repo, Enum.uniq(touched.changes ++ inner))

	process_ids = Enum.reject([Map.get(changes, :input_of_id), Map.get(changes, :output_of_id)], &is_nil/1)
	process_controls = lock_process_controls(repo, process_ids)

	provider = Map.get(changes, :provider_id)
	receiver = Map.get(changes, :receiver_id)
	admin_ids = [provider, receiver
		| Enum.map(Map.values(controls), & &1.controller_id)
			++ Enum.map(Map.values(process_controls), & &1.controller_id)]

	%__MODULE__{
		action: Map.get(changes, :action_id),
		provider_id: provider,
		receiver_id: receiver,
		source_id: Map.get(changes, :resource_inventoried_as_id),
		touched: touched,
		resources: resources,
		controls: controls,
		contained: contained,
		process_ids: process_ids,
		process_controls: process_controls,
		admin_of: Facts.admin_of(repo, ctx, admin_ids),
		claimable: MapSet.new(Config.claimable_agents()),
	}
end

@doc "Facts for `event.update`: the stored event (FOR UPDATE) and its agents."
@spec for_event(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_event(repo, ctx, id) do
	evt = repo.one(from e in EconomicEvent, where: e.id == ^id, lock: "FOR UPDATE")
	ids = if evt, do: [evt.provider_id, evt.receiver_id], else: []
	%__MODULE__{event: evt, admin_of: Facts.admin_of(repo, ctx, ids)}
end

defp contained_of(_repo, []), do: %{}
defp contained_of(repo, ids) do
	from(r in EconomicResource, where: r.contained_in_id in ^ids,
		select: {r.contained_in_id, r.id})
	|> repo.all()
	|> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
	|> Map.new(fn {k, v} -> {k, Enum.sort(v)} end)
end

defp lock_resources(_repo, []), do: %{}
defp lock_resources(repo, ids) do
	from(r in EconomicResource, where: r.id in ^ids, order_by: r.id, lock: "FOR UPDATE")
	|> repo.all()
	|> Map.new(&{&1.id, &1})
end

defp lock_controls(_repo, []), do: %{}
defp lock_controls(repo, ids) do
	from(c in ResourceControl, where: c.resource_id in ^ids,
		order_by: c.resource_id, lock: "FOR UPDATE")
	|> repo.all()
	|> Map.new(&{&1.resource_id, &1})
end

defp lock_process_controls(_repo, []), do: %{}
defp lock_process_controls(repo, ids) do
	from(c in ObjectControl, where: c.target_type == "process" and c.target_id in ^ids,
		order_by: c.target_id, lock: "FOR SHARE")
	|> repo.all()
	|> Map.new(&{&1.target_id, &1})
end
end
