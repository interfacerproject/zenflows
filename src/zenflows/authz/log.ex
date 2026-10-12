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

defmodule Zenflows.Authz.Log do
@moduledoc """
Append-only trace of permission changes and administrative metadata patches
(`zf_permission_log`). Metadata patches record changed keys/content fingerprints,
not raw metadata or fabricated physical events. Each entry is written in the
same transaction as the change it records;
actor, service and request id always come from the context.
"""

alias Ecto.Multi
alias Zenflows.Authz.{ExecutionContext, PermissionLog}

@type entry() :: %{
	required(:action) => String.t(),
	required(:target_type) => String.t(),
	required(:target_id) => String.t(),
	optional(atom()) => term(),
}

@spec insert(Ecto.Repo.t(), ExecutionContext.t(), entry())
	:: {:ok, PermissionLog.t()} | {:error, Ecto.Changeset.t()}
def insert(repo, ctx, entry) do
	entry
	|> Map.merge(%{
		actor_id: ExecutionContext.actor_id(ctx),
		service: ctx.via,
		request_id: ctx.request_id,
	})
	|> PermissionLog.changeset()
	|> repo.insert()
end

@spec multi_insert(Multi.t(), term(), ExecutionContext.t(), (map() -> nil | entry()))
	:: Multi.t()
def multi_insert(m, key, ctx, entry_fun) do
	Multi.run(m, key, fn repo, changes ->
		case entry_fun.(changes) do
			nil -> {:ok, nil}
			entry -> insert(repo, ctx, entry)
		end
	end)
end
end
