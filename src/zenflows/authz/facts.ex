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

defmodule Zenflows.Authz.Facts do
@moduledoc """
Everything a policy decision may look at.  Domain functions load it
(with row locks) inside their transaction, then hand it to the policy.
"""

import Ecto.Query

alias Zenflows.Authz.{ExecutionContext, ObjectControl, ResourceControl, Roles}
alias Zenflows.VF.{
	AgentRelationship,
	EconomicEvent,
	EconomicResource,
	Intent,
	Organization,
	Person,
	Process,
	Proposal,
	ProposedIntent,
	Satisfaction,
}

@type t() :: %__MODULE__{
	target: nil | struct() | map(),
	control: nil | ResourceControl.t() | ObjectControl.t(),
	admin_of: MapSet.t(String.t()),
	role_key: nil | String.t(),
	new_subject_id: nil | String.t(),
	active_admin_count: nil | non_neg_integer(),
	process_controls: %{String.t() => ObjectControl.t()},
	intent: nil | Intent.t(),
	intent_control: nil | ObjectControl.t(),
	event: nil | EconomicEvent.t(),
	sibling_parties: MapSet.t(String.t()),
	finished_only: boolean(),
}

defstruct target: nil,
	control: nil,
	admin_of: MapSet.new(),
	role_key: nil,
	new_subject_id: nil,
	active_admin_count: nil,
	process_controls: %{},
	intent: nil,
	intent_control: nil,
	event: nil,
	sibling_parties: MapSet.new(),
	finished_only: false

@doc """
The subset of `agent_ids` (nil entries ignored) where the acting Person
is an active `org.admin`.  Locks only those relationship rows FOR SHARE,
so a concurrent revoke of one of them serializes with the decision,
while admin rows of organizations the decision does not look at stay
unlocked (locking all of them used to deadlock against concurrent
grants/revokes in other organizations).  Callers pass exactly the
organization ids the decision needs.
"""
@spec admin_of(Ecto.Repo.t(), ExecutionContext.t(), [String.t() | nil]) :: MapSet.t(String.t())
def admin_of(repo, %ExecutionContext{principal: %Person{id: pid}}, agent_ids) when is_list(agent_ids) do
	case agent_ids |> Enum.reject(&is_nil/1) |> Enum.uniq() do
		[] ->
			MapSet.new()
		ids ->
			admin_role = Roles.id!(repo, "org.admin")
			from(r in AgentRelationship,
				where: r.subject_id == ^pid
					and r.object_id in ^ids
					and r.relationship_id == ^admin_role
					and is_nil(r.revoked_at),
				select: r.object_id,
				lock: "FOR SHARE")
			|> repo.all()
			|> MapSet.new()
	end
end
def admin_of(_repo, _ctx, agent_ids) when is_list(agent_ids), do: MapSet.new()

@spec for_resource(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_resource(repo, ctx, id) do
	target = repo.one(from r in EconomicResource, where: r.id == ^id, lock: "FOR UPDATE")
	control = repo.one(from c in ResourceControl, where: c.resource_id == ^id, lock: "FOR UPDATE")
	%__MODULE__{
		target: target,
		control: control,
		admin_of: admin_of(repo, ctx, [control && control.controller_id]),
	}
end

@spec for_organization(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_organization(repo, ctx, id) do
	%__MODULE__{
		target: repo.one(from o in Organization,
			where: o.id == ^id and o.type == :org, lock: "FOR UPDATE"),
		admin_of: admin_of(repo, ctx, [id]),
	}
end

@spec for_person(Ecto.Repo.t(), String.t()) :: t()
def for_person(repo, id) do
	%__MODULE__{
		target: repo.one(from p in Person, where: p.id == ^id and p.type == :per, lock: "FOR UPDATE"),
	}
end

@schemas %{"process" => Process, "proposal" => Proposal, "intent" => Intent}

@spec for_object(Ecto.Repo.t(), ExecutionContext.t(), String.t(), String.t()) :: t()
def for_object(repo, ctx, type, id) do
	schema = Map.fetch!(@schemas, type)
	target = repo.one(from t in schema, where: t.id == ^id, lock: "FOR UPDATE")
	control = lock_object_control(repo, type, id, "FOR UPDATE")
	%__MODULE__{target: target, control: control,
		admin_of: admin_of(repo, ctx, [control && control.controller_id])}
end

@spec for_intent_create(Ecto.Repo.t(), ExecutionContext.t(), map()) :: t()
def for_intent_create(repo, ctx, changes) do
	ids = Enum.reject([Map.get(changes, :input_of_id), Map.get(changes, :output_of_id)], &is_nil/1)
	controls = lock_object_controls(repo, "process", ids)
	%__MODULE__{target: changes, process_controls: controls,
		admin_of: admin_of(repo, ctx,
			[Map.get(changes, :provider_id), Map.get(changes, :receiver_id)
				| Enum.map(Map.values(controls), & &1.controller_id)])}
end

@spec for_intent_update(Ecto.Repo.t(), ExecutionContext.t(), String.t(), map()) :: t()
def for_intent_update(repo, ctx, id, params) do
	target = repo.one(from i in Intent, where: i.id == ^id, lock: "FOR UPDATE")
	control = lock_object_control(repo, "intent", id, "FOR UPDATE")
	siblings = sibling_parties(repo, id)
	ids = [control && control.controller_id,
		target && target.provider_id, target && target.receiver_id | MapSet.to_list(siblings)]
	%__MODULE__{target: target, control: control, sibling_parties: siblings,
		finished_only: Map.drop(params, [:id, "id"]) in [%{finished: true}, %{"finished" => true}],
		admin_of: admin_of(repo, ctx, ids)}
end

@spec for_proposed_intent_create(Ecto.Repo.t(), ExecutionContext.t(), String.t(), String.t()) :: t()
def for_proposed_intent_create(repo, ctx, proposal_id, intent_id) do
	control = lock_object_control(repo, "proposal", proposal_id, "FOR SHARE")
	intent = repo.get(Intent, intent_id)
	intent_control = lock_object_control(repo, "intent", intent_id, "FOR SHARE")
	%__MODULE__{control: control, intent: intent, intent_control: intent_control,
		admin_of: admin_of(repo, ctx, [control && control.controller_id,
			intent_control && intent_control.controller_id,
			intent && intent.provider_id, intent && intent.receiver_id])}
end

@spec for_proposed_intent(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_proposed_intent(repo, ctx, id) do
	target = repo.one(from p in ProposedIntent, where: p.id == ^id, lock: "FOR UPDATE")
	control = target && lock_object_control(repo, "proposal", target.published_in_id, "FOR SHARE")
	%__MODULE__{target: target, control: control,
		admin_of: admin_of(repo, ctx, [control && control.controller_id])}
end

@spec for_satisfaction_create(Ecto.Repo.t(), ExecutionContext.t(), map()) :: t()
def for_satisfaction_create(repo, ctx, changes) do
	event = case Map.get(changes, :satisfied_by_event_id) do
		nil -> nil
		eid -> repo.get(EconomicEvent, eid)
	end
	intent = case Map.get(changes, :satisfies_id) do
		nil -> nil
		iid -> repo.get(Intent, iid)
	end
	%__MODULE__{target: changes, event: event, intent: intent,
		admin_of: admin_of(repo, ctx, [event && event.provider_id, event && event.receiver_id])}
end

@spec for_satisfaction(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_satisfaction(repo, ctx, id) do
	target = repo.one(from s in Satisfaction, where: s.id == ^id, lock: "FOR UPDATE")
	event = target && target.satisfied_by_event_id && repo.get(EconomicEvent, target.satisfied_by_event_id)
	%__MODULE__{target: target, event: event,
		admin_of: admin_of(repo, ctx, [event && event.provider_id, event && event.receiver_id])}
end

defp lock_object_control(repo, type, id, "FOR UPDATE"),
	do: lock_object_control_update(repo, type, id)
defp lock_object_control(repo, type, id, "FOR SHARE"),
	do: lock_object_control_share(repo, type, id)

defp lock_object_control_update(repo, type, id) do
	from(c in ObjectControl, where: c.target_type == ^type and c.target_id == ^id, lock: "FOR UPDATE")
	|> repo.one()
end

defp lock_object_control_share(repo, type, id) do
	from(c in ObjectControl, where: c.target_type == ^type and c.target_id == ^id, lock: "FOR SHARE")
	|> repo.one()
end

defp lock_object_controls(_repo, _type, []), do: %{}
defp lock_object_controls(repo, type, ids) do
	from(c in ObjectControl, where: c.target_type == ^type and c.target_id in ^ids,
		order_by: c.target_id, lock: "FOR SHARE")
	|> repo.all()
	|> Map.new(&{&1.target_id, &1})
end

defp sibling_parties(repo, intent_id) do
	from(pi in ProposedIntent,
		join: sib in ProposedIntent, on: sib.published_in_id == pi.published_in_id,
		join: i in Intent, on: i.id == sib.publishes_id,
		where: pi.publishes_id == ^intent_id,
		select: [i.provider_id, i.receiver_id])
	|> repo.all()
	|> List.flatten()
	|> Enum.reject(&is_nil/1)
	|> MapSet.new()
end
end
