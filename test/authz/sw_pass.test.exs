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

defmodule ZenflowsTest.Authz.SWPass do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Zenflows.Authz.{ExecutionContext, PermissionLog, ResourceControl}

test "ensure_for_import creates admin-sourced control once, logged as import" do
	res = Factory.insert!(:economic_resource)
	Repo.delete_all(from c in ResourceControl, where: c.resource_id == ^res.id)
	ctx = ExecutionContext.service(:import, "rid")

	assert {:ok, %ResourceControl{source: :admin, controller_id: cid}} =
		ResourceControl.Domain.ensure_for_import(Repo, ctx, res)
	assert cid == res.primary_accountable_id
	assert {:ok, _} = ResourceControl.Domain.ensure_for_import(Repo, ctx, res)
	assert [%PermissionLog{service: :import, request_id: "rid"}] =
		Repo.all(from l in PermissionLog,
			where: l.target_id == ^res.id and l.action == "resource_control.set" and l.service == :import)
end

test "import_repos refuses non-admin contexts before any HTTP call" do
	per = Factory.insert!(:person)
	assert {:error, :forbidden} =
		Zenflows.SWPass.Domain.import_repos(Factory.ctx(per), "http://127.0.0.1:1/never")
end
end
