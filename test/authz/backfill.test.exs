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

defmodule ZenflowsTest.Authz.Backfill do
use ZenflowsTest.Help.EctoCase, async: false

import Ecto.Query

alias Zenflows.Authz.{Backfill, PermissionLog, ResourceControl}

test "trusts primaryAccountable, marks provenance, logs, is idempotent" do
	res = Factory.insert!(:economic_resource)
	Repo.delete_all(from c in ResourceControl, where: c.resource_id == ^res.id)

	assert Backfill.run(Repo) >= 1
	assert %ResourceControl{source: :backfill, controller_id: cid} =
		Repo.get_by!(ResourceControl, resource_id: res.id)
	assert cid == res.primary_accountable_id
	assert [%PermissionLog{service: :migration, actor_id: nil, after: %{"source" => "backfill"} = log_after}] =
		Repo.all(from l in PermissionLog, where: l.target_id == ^res.id and l.action == "resource_control.set" and l.service == :migration)
	assert log_after["controller_id"] == res.primary_accountable_id

	assert Backfill.run(Repo) == 0
end
end
