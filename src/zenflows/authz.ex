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

defmodule Zenflows.Authz do
@moduledoc """
Authorization checks inside domain transactions.  Domain functions call
`multi_authorize/5` before writing; the decision itself is
`Zenflows.Authz.Policy`.
"""

require Logger

alias Ecto.Multi
alias Zenflows.Authz.{Config, ExecutionContext, Facts, Policy}

@spec authorize(ExecutionContext.t(), String.t(), Facts.t(), Config.opts())
	:: :ok | {:error, :forbidden | :unauthenticated}
def authorize(ctx, action, facts, opts \\ Config.opts()) do
	case Policy.authorize(ctx, action, facts, opts) do
		:ok -> :ok
		{:error, reason} = err ->
			enforced? = Keyword.get(opts, :enforce, true)
			report_deny(ctx, action, facts, reason, enforced?)
			if enforced?, do: err, else: :ok
	end
end

@doc "Load facts with `facts_fun`, decide, and abort the multi on deny."
@spec multi_authorize(Multi.t(), term(), ExecutionContext.t(), String.t(),
		(Ecto.Repo.t(), map() -> Facts.t())) :: Multi.t()
def multi_authorize(m, key, ctx, action, facts_fun) do
	Multi.run(m, key, fn repo, changes ->
		facts = facts_fun.(repo, changes)
		with :ok <- authorize(ctx, action, facts), do: {:ok, facts}
	end)
end

@doc "Put the authorized target under `key`, or fail with \"not found\"."
@spec multi_target(Multi.t(), term(), term()) :: Multi.t()
def multi_target(m, key, authz_key) do
	Multi.run(m, key, fn _repo, changes ->
		case Map.fetch!(changes, authz_key) do
			%Facts{target: nil} -> {:error, "not found"}
			%Facts{target: target} -> {:ok, target}
		end
	end)
end

defp report_deny(ctx, action, facts, reason, enforced?) do
	meta = %{
		actor_id: ExecutionContext.actor_id(ctx),
		action: action,
		target_id: target_id(facts),
		request_id: ctx.request_id,
		reason: reason,
		enforced: enforced?,
	}
	:telemetry.execute([:zenflows, :authz, :deny], %{count: 1}, meta)
	Logger.info("authz deny", Map.to_list(meta))
end

defp target_id(%Facts{target: %{id: id}}), do: id
defp target_id(_), do: nil
end
