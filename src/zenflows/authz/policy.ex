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

defmodule Zenflows.Authz.Policy do
@moduledoc """
Deny-by-default authorization decisions.  Pure: it never touches the
database; everything it needs is in `Zenflows.Authz.Facts` (most
actions, including processes, proposals, intents, proposed intents,
and satisfactions) or `Zenflows.Authz.EventFacts`
(`event.create`/`event.update`, decided by `Zenflows.Authz.EventPolicy`).
"""

alias Zenflows.Authz.{Config, EventFacts, EventPolicy, ExecutionContext, Facts, ObjectControl}
alias Zenflows.VF.{EconomicEvent, Intent, Person, ProposedIntent}

@actions ~w[
	resource.create resource.update resource.delete
	organization.create organization.update organization.delete
	organization.assign_admin
	relationship.grant relationship.revoke
	relationship.create relationship.update relationship.delete
	role.update role.delete
	person.create person.update person.delete
	sw_pass.import resource_control.set
	event.create event.update
	object_control.assign
	process.create process.update process.delete
	proposal.create proposal.update proposal.delete
	intent.create intent.update intent.delete
	proposed_intent.create proposed_intent.delete
	satisfaction.create satisfaction.update satisfaction.delete
]

@doc "Every action the policy knows about."
@spec actions() :: [String.t()]
def actions(), do: @actions

@spec authorize(ExecutionContext.t(), String.t(), Facts.t() | EventFacts.t(), Config.opts())
	:: :ok | {:error, :forbidden | :unauthenticated} | {:error, :forbidden, EventPolicy.rule()}
def authorize(%ExecutionContext{principal: %Person{id: pid}}, action, %EventFacts{} = f, _opts)
		when action in ~w[event.create event.update],
	do: EventPolicy.decide(pid, action, f)
def authorize(%ExecutionContext{principal: %Person{}}, _action, %EventFacts{}, _opts),
	do: {:error, :forbidden}
def authorize(%ExecutionContext{principal: principal}, action, facts, opts)
		when is_struct(facts, Facts) or is_struct(facts, EventFacts) do
	if action in @actions,
		do: decide(principal, action, facts, opts),
		else: {:error, :forbidden}
end

defp decide(:anonymous, _action, _facts, opts) do
	if Keyword.get(opts, :allow_unchecked, false),
		do: :ok,
		else: {:error, :unauthenticated}
end
defp decide({:service, _name, allowed}, action, _facts, _opts) do
	if MapSet.member?(allowed, action), do: :ok, else: {:error, :forbidden}
end
defp decide(%Person{id: pid}, action, facts, _opts) do
	if person_may?(pid, action, facts), do: :ok, else: {:error, :forbidden}
end

# `resource.create`/`organization.create` stay open here: any signer
# may create resources (through events) and organizations.  Events
# themselves are decided above, by `EventPolicy.decide/3` via the
# `event.create`/`event.update` clauses of `authorize/4`, not by this
# function.
defp person_may?(_pid, action, _f) when action in ~w[resource.create organization.create],
	do: true
defp person_may?(pid, action, %Facts{control: %{controller_id: cid}} = f)
		when action in ~w[resource.update resource.delete],
	do: cid == pid or admin?(f, cid)
defp person_may?(_pid, action, %Facts{target: %{id: oid}} = f)
		when action in ~w[organization.update organization.delete],
	do: admin?(f, oid)
defp person_may?(_pid, "relationship.grant", %Facts{target: %{object_id: oid}} = f),
	do: admin?(f, oid)
defp person_may?(_pid, "relationship.revoke", %Facts{target: %{object_id: oid}, role_key: rk} = f),
	do: admin?(f, oid) and (rk != "org.admin" or (f.active_admin_count || 0) > 1)
defp person_may?(pid, action, %Facts{target: %{subject_id: sid}} = f)
		when action in ~w[relationship.create relationship.delete],
	do: subject_ok?(pid, f, sid)
defp person_may?(pid, "relationship.update",
		%Facts{target: %{subject_id: sid, object_id: oid}, role_key: rk} = f) do
	if rk != nil do
		admin?(f, oid)
	else
		subject_ok?(pid, f, sid)
			and (f.new_subject_id == nil or subject_ok?(pid, f, f.new_subject_id))
	end
end
defp person_may?(_pid, action, %Facts{target: %{system_key: sk}})
		when action in ~w[role.update role.delete],
	do: sk == nil
defp person_may?(pid, "person.update", %Facts{target: %Person{id: id}}),
	do: id == pid
defp person_may?(_pid, action, _f) when action in ~w[process.create proposal.create],
	do: true
defp person_may?(pid, action, %Facts{control: %ObjectControl{} = c} = f)
		when action in ~w[process.update process.delete proposal.update proposal.delete intent.delete],
	do: object_type_ok?(action, c.target_type) and controls?(pid, f, c)
defp person_may?(pid, "intent.create", %Facts{target: %{} = t} = f) do
	case Enum.reject([Map.get(t, :input_of_id), Map.get(t, :output_of_id)], &is_nil/1) do
		[] -> acts_for?(pid, f, Map.get(t, :provider_id)) or acts_for?(pid, f, Map.get(t, :receiver_id))
		ids -> Enum.all?(ids, &controls?(pid, f, Map.get(f.process_controls, &1)))
	end
end
defp person_may?(pid, "intent.update", %Facts{target: %Intent{} = i} = f) do
	base = controls?(pid, f, f.control)
		or acts_for?(pid, f, i.provider_id) or acts_for?(pid, f, i.receiver_id)
		or (f.finished_only and Enum.any?(f.sibling_parties, &acts_for?(pid, f, &1)))
	# Updates are judged only on the old state above; a structural
	# change (new provider/receiver/process) must additionally pass the
	# same rule a fresh `intent.create` with that shape would, AND
	# (`detach_ok?/3`) a named party may not use that same rule's
	# process-less fallback to detach from a process they never
	# controlled in the first place.
	base
		and (f.new_target == nil or person_may?(pid, "intent.create", %{f | target: f.new_target}))
		and detach_ok?(pid, f, i)
end
defp person_may?(pid, "proposed_intent.create", %Facts{intent: %Intent{} = i} = f) do
	(controls?(pid, f, f.control) and type_ok?(f.control, "proposal"))
		and ((controls?(pid, f, f.intent_control) and type_ok?(f.intent_control, "intent"))
			or acts_for?(pid, f, i.provider_id) or acts_for?(pid, f, i.receiver_id))
end
defp person_may?(pid, "proposed_intent.delete", %Facts{target: %ProposedIntent{}} = f),
	do: controls?(pid, f, f.control) and type_ok?(f.control, "proposal")
defp person_may?(pid, "satisfaction.create", %Facts{event: %EconomicEvent{} = e, intent: %Intent{} = i} = f) do
	event_agents = Enum.reject([e.provider_id, e.receiver_id], &is_nil/1)
	intent_agents = Enum.reject([i.provider_id, i.receiver_id], &is_nil/1)
	Enum.any?(event_agents, &acts_for?(pid, f, &1))
		and Enum.any?(event_agents, &(&1 in intent_agents))
end
defp person_may?(pid, "satisfaction.update", %Facts{event: %EconomicEvent{} = e} = f) do
	base = acts_for?(pid, f, e.provider_id) or acts_for?(pid, f, e.receiver_id)
	# As with `intent.update`: the old state alone decides the base
	# case above; re-pointing (`repoint?`, which covers switching to a
	# bare commitment -- `new_event` nil -- just as much as pointing at
	# a different event) or naming a different intent must additionally
	# pass the `satisfaction.create` rule for the new pair.  `new_event`
	# is used as-is (never falls back to the old `event`) so that
	# re-pointing to "no event" is correctly judged against `nil`, not
	# against the event being replaced.
	# A changed `satisfies_id` (`retarget?`) is judged against the new
	# intent only: if it doesn't exist (`new_intent` nil) the create
	# clause doesn't match and the update is denied.
	base and (
		(not f.repoint? and not f.retarget?)
			or person_may?(pid, "satisfaction.create",
				%{f | event: (if f.repoint?, do: f.new_event, else: f.event),
					intent: (if f.retarget?, do: f.new_intent, else: f.intent)}))
end
defp person_may?(pid, "satisfaction.delete", %Facts{event: %EconomicEvent{} = e} = f),
	do: acts_for?(pid, f, e.provider_id) or acts_for?(pid, f, e.receiver_id)
defp person_may?(_pid, _action, _facts), do: false

defp admin?(%Facts{admin_of: set}, id), do: MapSet.member?(set, id)

defp subject_ok?(pid, f, sid), do: sid == pid or admin?(f, sid)

defp acts_for?(_pid, _f, nil), do: false
defp acts_for?(pid, f, id), do: id == pid or MapSet.member?(f.admin_of, id)

defp controls?(_pid, _f, nil), do: false
defp controls?(pid, f, %{controller_id: cid}), do: acts_for?(pid, f, cid)

# `process.update`/`process.delete` etc. only make sense against a
# control row of the matching object type (the action's prefix); this
# guards against a stale/mismatched control row silently authorizing
# the wrong kind of object.
defp object_type_ok?(action, type) do
	[prefix | _] = String.split(action, ".", parts: 2)
	prefix == type
end

defp type_ok?(nil, _type), do: true
defp type_ok?(%ObjectControl{target_type: t}, type), do: t == type

# For each of `input_of_id`/`output_of_id` that `new_target` actually
# changes away from `i`'s current value (nil included: detaching
# counts), the signer must control that *old*, non-nil process.
# Without this, a named party could use `intent.create`'s process-less
# fallback (acting for a party is enough when the new state has no
# process) to unilaterally detach from a process someone else
# controls, simply by removing or swapping out the process reference.
defp detach_ok?(_pid, %Facts{new_target: nil}, _i), do: true
defp detach_ok?(pid, f, i) do
	~w[input_of_id output_of_id]a
	|> Enum.filter(&(Map.get(f.new_target, &1) != Map.get(i, &1)))
	|> Enum.map(&Map.get(i, &1))
	|> Enum.reject(&is_nil/1)
	|> Enum.all?(&controls?(pid, f, Map.get(f.process_controls, &1)))
end
end
