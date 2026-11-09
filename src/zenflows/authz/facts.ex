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

alias Zenflows.Authz.{ExecutionContext, ResourceControl, Roles}
alias Zenflows.VF.{AgentRelationship, EconomicResource, Organization, Person}

@type t() :: %__MODULE__{
	target: nil | struct() | map(),
	control: nil | ResourceControl.t(),
	admin_of: MapSet.t(String.t()),
	role_key: nil | String.t(),
	new_subject_id: nil | String.t(),
	active_admin_count: nil | non_neg_integer(),
}

defstruct target: nil,
	control: nil,
	admin_of: MapSet.new(),
	role_key: nil,
	new_subject_id: nil,
	active_admin_count: nil

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
end
