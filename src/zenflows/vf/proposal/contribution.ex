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

defmodule Zenflows.VF.Proposal.Contribution do
@moduledoc """
Atomic acceptance of a contribution proposal, as `proposeContribution`
shapes it (see `docs/atomic-accept-contribution.md`).

The owner's cite/accept/modify events and the three satisfactions are
written in one transaction, through the existing `event.create` and
`satisfaction.create` policy.  Accepting an accepted proposal returns its
events and writes nothing.
"""

import Ecto.Query

alias Ecto.Multi
alias Zenflows.Authz.ExecutionContext
alias Zenflows.DB.{Repo, Schema}
alias Zenflows.VF.{EconomicEvent, EconomicResource, Intent, Proposal, ProposedIntent, Satisfaction}

@type result() :: %{
	proposal: Proposal.t(),
	cite_event: EconomicEvent.t(),
	accept_event: EconomicEvent.t(),
	modify_event: EconomicEvent.t(),
}

@spec accept(ExecutionContext.t(), Schema.id())
	:: {:ok, result()} | {:error, atom() | String.t() | Ecto.Changeset.t()}
def accept(%ExecutionContext{} = ctx, proposal_id) do
	Multi.new()
	# Unlocked read, only to learn which rows to lock.
	|> Multi.run(:shape, fn repo, _ -> shape(primary_intents(repo, proposal_id, false)) end)
	# Lock order: resource rows, then intent rows (slice-3 §4.1).
	|> Multi.run(:resources, fn repo, %{shape: s} -> lock_resources(repo, s) end)
	|> Multi.run(:locked, fn repo, %{shape: s} ->
		with {:ok, locked} <- shape(primary_intents(repo, proposal_id, true)) do
			if same_rows?(locked, s), do: {:ok, locked}, else: {:error, :proposal_not_pending}
		end
	end)
	|> Multi.run(:state, fn repo, %{locked: s} -> state(repo, s) end)
	|> Multi.merge(fn
		%{state: {:accepted, events}} -> Multi.put(Multi.new(), :events, events)
		%{state: :pending, locked: s, resources: res} -> write(ctx, s, res)
	end)
	|> Repo.transaction()
	|> case do
		{:ok, %{events: events}} ->
			{:ok, Map.put(events, :proposal, Proposal.Domain.one!(proposal_id))}
		{:error, _, reason, _} ->
			{:error, reason}
	end
end

defp primary_intents(repo, proposal_id, lock?) do
	query =
		from i in Intent,
			join: pi in ProposedIntent, on: pi.publishes_id == i.id,
			where: pi.published_in_id == ^proposal_id and not pi.reciprocal,
			order_by: i.id
	query = if lock?, do: from(i in query, lock: "FOR SHARE"), else: query
	repo.all(query)
end

defp shape(intents) do
	case Enum.group_by(intents, & &1.action_id) do
		%{"cite" => [cite], "accept" => [accept], "modify" => [modify]} when length(intents) == 3 ->
			process = accept.input_of_id
			ok? =
				process != nil
				and cite.input_of_id == process
				and modify.output_of_id == process
				and cite.provider_id != nil
				and accept.receiver_id != nil
				and modify.receiver_id == accept.receiver_id
				and accept.resource_inventoried_as_id != nil
				and modify.resource_inventoried_as_id == accept.resource_inventoried_as_id
				and cite.resource_inventoried_as_id != nil
				and cite.resource_inventoried_as_id != accept.resource_inventoried_as_id
			if ok? do
				{:ok, %{
					cite: cite, accept: accept, modify: modify, process: process,
					owner: accept.receiver_id, proposer: cite.provider_id,
					origin: accept.resource_inventoried_as_id, fork: cite.resource_inventoried_as_id,
				}}
			else
				{:error, :not_contribution_proposal}
			end
		_ ->
			{:error, :not_contribution_proposal}
	end
end

defp same_rows?(a, b),
	do: Map.take(a, ~w[process owner proposer origin fork]a) == Map.take(b, ~w[process owner proposer origin fork]a)

defp lock_resources(repo, s) do
	rows = repo.all(from r in EconomicResource,
		where: r.id in ^[s.origin, s.fork], order_by: r.id, lock: "FOR UPDATE")
	case Enum.find(rows, &(&1.id == s.origin)) do
		nil -> {:error, :not_contribution_proposal}
		origin -> {:ok, %{origin: origin}}
	end
end

defp state(repo, s) do
	intents = [s.cite, s.accept, s.modify]
	sats = repo.all(from x in Satisfaction, where: x.satisfies_id in ^Enum.map(intents, & &1.id))
	by_intent = Enum.group_by(sats, & &1.satisfies_id)

	cond do
		sats == [] and not Enum.any?(intents, & &1.finished) ->
			{:ok, :pending}
		Enum.all?(intents, &match?([%{satisfied_by_event_id: e}] when e != nil, Map.get(by_intent, &1.id))) ->
			event = fn intent -> EconomicEvent.Domain.one!(repo, hd(by_intent[intent.id]).satisfied_by_event_id) end
			{:ok, {:accepted, %{cite_event: event.(s.cite), accept_event: event.(s.accept), modify_event: event.(s.modify)}}}
		true ->
			{:error, :proposal_not_pending}
	end
end

defp write(ctx, s, %{origin: origin}) do
	now = DateTime.utc_now()
	evt = fn intent, params ->
		Map.merge(%{
			resource_quantity: %{
				has_numerical_value: intent.resource_quantity_has_numerical_value,
				has_unit_id: intent.resource_quantity_has_unit_id,
			},
			has_point_in_time: now,
		}, params)
	end

	Multi.new()
	|> Multi.run(:metadata, fn _, _ -> with_relation(origin.metadata, s.fork) end)
	|> EconomicEvent.Domain.multi_insert(ctx, :cite_event, evt.(s.cite, %{
		action_id: "cite", input_of_id: s.process, provider_id: s.proposer, receiver_id: s.owner,
		resource_inventoried_as_id: s.fork}), nil)
	|> EconomicEvent.Domain.multi_insert(ctx, :accept_event, evt.(s.accept, %{
		action_id: "accept", input_of_id: s.process, provider_id: s.owner, receiver_id: s.owner,
		resource_inventoried_as_id: s.origin}), nil)
	|> Multi.merge(fn %{metadata: metadata} ->
		EconomicEvent.Domain.multi_insert(Multi.new(), ctx, :modify_event, evt.(s.modify, %{
			action_id: "modify", output_of_id: s.process, provider_id: s.owner, receiver_id: s.owner,
			resource_inventoried_as_id: s.origin, resource_metadata: metadata}), nil)
	end)
	|> Multi.merge(fn changes ->
		[{s.cite, :cite_event}, {s.accept, :accept_event}, {s.modify, :modify_event}]
		|> Enum.reduce(Multi.new(), fn {intent, key}, m ->
			Satisfaction.Domain.multi_insert(m, ctx, :"#{key}_satisfaction", %{
				satisfies_id: intent.id,
				satisfied_by_event_id: Map.fetch!(changes, key).id,
				resource_quantity: %{
					has_numerical_value: intent.resource_quantity_has_numerical_value,
					has_unit_id: intent.resource_quantity_has_unit_id,
				},
			})
		end)
	end)
	|> Multi.run(:events, fn _, changes ->
		{:ok, Map.take(changes, [:cite_event, :accept_event, :modify_event])}
	end)
end

# The origin's current (locked) metadata with the fork appended to
# `relations` once; every other key is kept.
defp with_relation(metadata, fork) do
	metadata = metadata || %{}
	case Map.get(metadata, "relations") do
		nil -> {:ok, Map.put(metadata, "relations", [fork])}
		list when is_list(list) ->
			{:ok, if(fork in list, do: metadata, else: Map.put(metadata, "relations", list ++ [fork]))}
		_ -> {:error, :invalid_metadata_patch}
	end
end
end
