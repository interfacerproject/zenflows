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

defmodule Zenflows.Authz.Roles do
@moduledoc "System AgentRelationshipRoles, looked up by their stable `system_key`."

import Ecto.Query

alias Zenflows.VF.AgentRelationshipRole

@keys ~w[org.admin org.member]

@spec keys() :: [String.t()]
def keys(), do: @keys

@spec id!(Ecto.Repo.t(), String.t()) :: String.t()
def id!(repo, key) when key in @keys do
	repo.one!(from r in AgentRelationshipRole, where: r.system_key == ^key, select: r.id)
end

@doc "The system key of a role id, or nil for user-defined roles."
@spec key_of(Ecto.Repo.t(), nil | String.t()) :: nil | String.t()
def key_of(_repo, nil), do: nil
def key_of(repo, role_id) do
	repo.one(from r in AgentRelationshipRole, where: r.id == ^role_id, select: r.system_key)
end
end
