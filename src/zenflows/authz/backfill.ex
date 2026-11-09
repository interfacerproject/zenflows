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

defmodule Zenflows.Authz.Backfill do
@moduledoc """
One-off backfill of `zf_resource_control` for resources created before
authorization existed.  Team decision: the existing `primaryAccountable`
is trusted as controller; `source = backfill` keeps it distinguishable.
Uses plain SQL so later schema changes don't break the migration.
"""

alias Zenflows.DB.ID

@batch 1000

@spec run(Ecto.Repo.t()) :: non_neg_integer()
def run(repo) do
	%{rows: rows} = repo.query!("""
		SELECT r.id, r.primary_accountable_id
		FROM vf_economic_resource r
		LEFT JOIN zf_resource_control c ON c.resource_id = r.id
		WHERE c.resource_id IS NULL AND r.primary_accountable_id IS NOT NULL
		""")
	now = DateTime.utc_now()

	rows
	|> Enum.chunk_every(@batch)
	|> Enum.each(fn chunk ->
		repo.insert_all("zf_resource_control", Enum.map(chunk, fn [res_id, pa_id] ->
			%{resource_id: res_id, controller_id: pa_id, source: "backfill", epoch: 0, updated_at: now}
		end))
		repo.insert_all("zf_permission_log", Enum.map(chunk, fn [res_id, pa_id] ->
			{:ok, id} = ID.dump(ID.gen())
			{:ok, controller} = ID.load(pa_id)
			%{
				id: id,
				service: "migration",
				action: "resource_control.set",
				target_type: "economic_resource",
				target_id: res_id,
				subject_id: pa_id,
				after: %{controller_id: controller, source: "backfill"},
				inserted_at: now,
			}
		end))
	end)

	length(rows)
end
end
