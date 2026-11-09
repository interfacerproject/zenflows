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

defmodule Zenflows.Authz.EventPolicy do
@moduledoc """
Who may emit which economic event.  Pure: everything comes from
`Zenflows.Authz.EventFacts`.

- Agent rule: the signer acts for the provider or the receiver.
- Resource rule: the signer controls every resource the event changes
  (and, for containers, every contained resource).
- Claim rule: resources of a claimable agent may be moved by a
  transfer-type event into a new resource of the signer.
"""

alias Zenflows.Authz.EventFacts

@kinds %{
	"raise" => :create, "produce" => :create,
	"lower" => :change, "consume" => :change, "accept" => :change,
	"modify" => :change, "pickup" => :change, "dropoff" => :change,
	"transfer" => :transfer, "transferAllRights" => :transfer,
	"transferCustody" => :transfer, "move" => :transfer,
	"cite" => :reference, "use" => :reference,
	"work" => :none, "deliverService" => :none,
	"combine" => :unsupported, "separate" => :unsupported,
}

@claim_actions ~w[transfer transferAllRights transferCustody]

@type kind() :: :create | :change | :transfer | :reference | :none | :unsupported
@type touched() :: %{
	changes: [String.t()],
	references: [String.t()],
	creates: :none | :resource | :destination,
}
@type rule() :: :agent | :resource | :claim | :unsupported

@spec actions() :: [String.t()]
def actions(), do: Map.keys(@kinds)

@spec kind(nil | String.t()) :: kind()
def kind(action), do: Map.get(@kinds, action, :unsupported)

@doc "Resources an event with these (validated changeset) changes touches."
@spec touched(map()) :: touched()
def touched(changes) do
	res = Map.get(changes, :resource_inventoried_as_id)
	to_res = Map.get(changes, :to_resource_inventoried_as_id)
	case kind(Map.get(changes, :action_id)) do
		:create ->
			creates = if Map.get(changes, :resource_conforms_to_id), do: :resource, else: :none
			%{changes: List.wrap(res), references: [], creates: creates}
		:change ->
			%{changes: List.wrap(res), references: [], creates: :none}
		:transfer ->
			creates = if to_res, do: :none, else: :destination
			%{changes: Enum.reject([res, to_res], &is_nil/1), references: [], creates: creates}
		:reference ->
			%{changes: [], references: List.wrap(res), creates: :none}
		_ ->
			%{changes: [], references: [], creates: :none}
	end
end

@spec decide(String.t(), String.t(), EventFacts.t()) :: :ok | {:error, :forbidden, rule()}
def decide(pid, "event.update", %EventFacts{event: %{provider_id: p, receiver_id: r}} = f) do
	if acts_for?(pid, f, p) or acts_for?(pid, f, r),
		do: :ok,
		else: {:error, :forbidden, :agent}
end
def decide(pid, "event.create", %EventFacts{} = f) do
	cond do
		kind(f.action) == :unsupported ->
			{:error, :forbidden, :unsupported}
		not (acts_for?(pid, f, f.provider_id) or acts_for?(pid, f, f.receiver_id)) ->
			{:error, :forbidden, :agent}
		true ->
			check_changes(pid, f)
	end
end
def decide(_pid, _action, _facts), do: {:error, :forbidden, :agent}

@doc "Whether an authorized `event.create` was a claim (for the permission log)."
@spec claim?(String.t(), EventFacts.t()) :: boolean()
def claim?(pid, %EventFacts{source_id: src} = f) do
	src != nil and claimable_source?(f, src) and not controls_all?(pid, f, src)
		and claim_ok?(pid, f, src)
end

defp check_changes(pid, f) do
	Enum.reduce_while(f.touched.changes, :ok, fn id, :ok ->
		case change_ok(pid, f, id) do
			:ok -> {:cont, :ok}
			err -> {:halt, err}
		end
	end)
end

defp change_ok(pid, f, id) do
	cond do
		controls_all?(pid, f, id) -> :ok
		claimable_source?(f, id) ->
			if claim_ok?(pid, f, id), do: :ok, else: {:error, :forbidden, :claim}
		true -> {:error, :forbidden, :resource}
	end
end

# The resource and everything it contains.
defp controls_all?(pid, f, id),
	do: Enum.all?([id | Map.get(f.contained, id, [])], &controls?(pid, f, &1))

defp controls?(pid, f, id) do
	case Map.get(f.controls, id) do
		%{controller_id: cid} -> acts_for?(pid, f, cid)
		nil -> false
	end
end

defp claimable_source?(f, id) do
	case Map.get(f.controls, id) do
		%{controller_id: cid} -> MapSet.member?(f.claimable, cid)
		nil -> false
	end
end

defp claim_ok?(pid, f, id) do
	f.action in @claim_actions
		and f.touched.creates == :destination
		and id == f.source_id
		and acts_for?(pid, f, f.receiver_id)
		and Map.get(f.contained, id, []) == []
end

defp acts_for?(_pid, _f, nil), do: false
defp acts_for?(pid, f, id), do: id == pid or MapSet.member?(f.admin_of, id)
end
