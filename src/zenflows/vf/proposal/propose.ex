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

defmodule Zenflows.VF.Proposal.Propose do
@moduledoc """
Atomic creation of a contribution proposal, in the shape
`Proposal.Contribution.accept/2` accepts (see
`docs/atomic-propose-contribution.md`).

Proposer = the signer, who must control the fork; owner = the origin's
controller (a Person or an Organization).  Every write goes through the
existing domain functions and their policy, in one transaction.  A pending
proposal by the same proposer for the same fork → origin is returned
instead of creating another.
"""

import Ecto.Query

alias Ecto.Multi
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, ResourceControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.{EconomicResource, Intent, Process, Proposal, ProposedIntent, Satisfaction}

@type result() :: %{
	proposal: Proposal.t(),
	process: Process.t(),
	cite_intent: Intent.t(),
	accept_intent: Intent.t(),
	modify_intent: Intent.t(),
	created: boolean(),
}

@spec propose(ExecutionContext.t(), map())
	:: {:ok, result()} | {:error, term()}
def propose(%ExecutionContext{} = ctx, %{resource_forked_id: fork, resource_origin_id: origin} = params) do
	Multi.new()
	|> Multi.run(:proposer, fn _, _ -> proposer(ctx) end)
	|> Multi.run(:resources, fn repo, _ -> lock_resources(repo, fork, origin) end)
	|> Multi.run(:fork_control, fn repo, _ ->
		with :ok <- Authz.authorize(ctx, "resource.update", Facts.for_resource(repo, ctx, fork)),
			do: {:ok, nil}
	end)
	|> Multi.run(:owner, fn repo, _ ->
		case repo.one(from c in ResourceControl, where: c.resource_id == ^origin, lock: "FOR SHARE") do
			%{controller_id: id} when id != nil -> {:ok, id}
			_ -> {:error, {:bad_user_input, "the origin resource has no controller"}}
		end
	end)
	|> Multi.run(:existing, fn repo, %{proposer: p, owner: o} -> {:ok, pending(repo, p, o, fork, origin)} end)
	|> Multi.merge(fn
		%{existing: %{} = found} -> Multi.put(Multi.new(), :result, Map.put(found, :created, false))
		%{existing: nil} = changes -> write(ctx, params, changes)
	end)
	|> Repo.transaction()
	|> case do
		{:ok, %{result: result}} -> {:ok, result}
		{:error, _, reason, _} -> {:error, reason}
	end
end

defp proposer(%ExecutionContext{principal: %{id: id}}), do: {:ok, id}
defp proposer(_), do: {:error, :unauthenticated}

defp lock_resources(_repo, same, same), do: {:error, {:bad_user_input, "the fork and the origin must differ"}}
defp lock_resources(repo, fork, origin) do
	rows = repo.all(from r in EconomicResource,
		where: r.id in ^[fork, origin], order_by: r.id, lock: "FOR UPDATE")
	case {Enum.find(rows, &(&1.id == fork)), Enum.find(rows, &(&1.id == origin))} do
		{%{} = f, %{} = o} -> {:ok, %{fork: f, origin: o}}
		_ -> {:error, {:bad_user_input, "unknown resource"}}
	end
end

# The oldest pending contribution proposal by `proposer` for fork → origin
# naming `owner`, with its process and intents; nil if there is none.
defp pending(repo, proposer, owner, fork, origin) do
	candidates =
		from(pi in ProposedIntent,
			join: i in Intent, on: i.id == pi.publishes_id,
			where: not pi.reciprocal and i.action_id == "cite"
				and i.resource_inventoried_as_id == ^fork and i.provider_id == ^proposer,
			select: pi.published_in_id, distinct: true)
		|> repo.all()
		|> Enum.sort()

	Enum.find_value(candidates, fn proposal_id ->
		intents = repo.all(from i in Intent,
			join: pi in ProposedIntent, on: pi.publishes_id == i.id,
			where: pi.published_in_id == ^proposal_id and not pi.reciprocal)
		with %{"cite" => [cite], "accept" => [accept], "modify" => [modify]} when length(intents) == 3 <-
				Enum.group_by(intents, & &1.action_id),
			true <- accept.resource_inventoried_as_id == origin and modify.resource_inventoried_as_id == origin
				and accept.receiver_id == owner and modify.receiver_id == owner
				and cite.input_of_id != nil and accept.input_of_id == cite.input_of_id
				and modify.output_of_id == cite.input_of_id,
			false <- Enum.any?(intents, & &1.finished),
			false <- repo.exists?(from s in Satisfaction, where: s.satisfies_id in ^Enum.map(intents, & &1.id)) do
			%{
				proposal: Proposal.Domain.one!(repo, proposal_id),
				process: Process.Domain.one!(repo, cite.input_of_id),
				cite_intent: cite, accept_intent: accept, modify_intent: modify,
			}
		else
			_ -> nil
		end
	end)
end

defp write(ctx, params, %{proposer: proposer, owner: owner, resources: %{fork: fork, origin: origin}}) do
	now = DateTime.utc_now()
	qty = fn res -> %{
		has_numerical_value: res.onhand_quantity_has_numerical_value,
		has_unit_id: res.onhand_quantity_has_unit_id,
	} end

	Multi.new()
	|> Multi.run(:process, fn _, _ ->
		Process.Domain.create(ctx, %{name: Map.get(params, :name) || "contribution proposal"})
	end)
	|> Multi.run(:cite_intent, fn _, %{process: p} ->
		Intent.Domain.create(ctx, %{action_id: "cite", input_of_id: p.id, provider_id: proposer,
			resource_inventoried_as_id: fork.id, resource_quantity: qty.(fork), has_point_in_time: now})
	end)
	|> Multi.run(:accept_intent, fn _, %{process: p} ->
		Intent.Domain.create(ctx, %{action_id: "accept", input_of_id: p.id, receiver_id: owner,
			resource_inventoried_as_id: origin.id, resource_quantity: qty.(origin), has_point_in_time: now})
	end)
	|> Multi.run(:modify_intent, fn _, %{process: p} ->
		Intent.Domain.create(ctx, %{action_id: "modify", output_of_id: p.id, receiver_id: owner,
			resource_inventoried_as_id: origin.id, resource_quantity: qty.(origin), has_point_in_time: now})
	end)
	|> Multi.run(:proposal, fn _, _ ->
		Proposal.Domain.create(ctx, %{name: Map.get(params, :name) || "Contribution to resource",
			note: Map.get(params, :note)})
	end)
	|> Multi.run(:links, fn _, %{proposal: proposal} = changes ->
		Enum.reduce_while([:cite_intent, :accept_intent, :modify_intent], {:ok, []}, fn key, {:ok, acc} ->
			case ProposedIntent.Domain.create(ctx, %{published_in_id: proposal.id,
					publishes_id: Map.fetch!(changes, key).id, reciprocal: false}) do
				{:ok, link} -> {:cont, {:ok, [link | acc]}}
				error -> {:halt, error}
			end
		end)
	end)
	|> Multi.run(:result, fn _, changes ->
		{:ok, changes
			|> Map.take([:proposal, :process, :cite_intent, :accept_intent, :modify_intent])
			|> Map.put(:created, true)}
	end)
end
end
