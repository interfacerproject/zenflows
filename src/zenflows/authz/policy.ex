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
actions) or `Zenflows.Authz.EventFacts` (`event.create`/`event.update`,
decided by `Zenflows.Authz.EventPolicy`).
"""

alias Zenflows.Authz.{Config, EventFacts, EventPolicy, ExecutionContext, Facts}
alias Zenflows.VF.Person

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
defp person_may?(_pid, _action, _facts), do: false

defp admin?(%Facts{admin_of: set}, id), do: MapSet.member?(set, id)

defp subject_ok?(pid, f, sid), do: sid == pid or admin?(f, sid)
end
