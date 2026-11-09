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

defmodule ZenflowsTest.Authz.Schema do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.Authz.{PermissionLog, ResourceControl}
alias Zenflows.VF.AgentRelationshipRole

test "system roles are seeded" do
	for key <- ["org.admin", "org.member"] do
		assert %AgentRelationshipRole{system_key: ^key} =
			Repo.get_by(AgentRelationshipRole, system_key: key)
	end
end

describe "zf_permission_log" do
	setup do
		log =
			%{service: :migration, action: "test", target_type: "x", target_id: Factory.id()}
			|> PermissionLog.changeset()
			|> Repo.insert!()
		%{log: log}
	end

	test "inserted_at is set by the database", %{log: log} do
		assert %DateTime{} = log.inserted_at
	end

	test "rejects UPDATE", %{log: log} do
		assert_raise Postgrex.Error, ~r/append-only/, fn ->
			log |> Ecto.Changeset.change(action: "changed") |> Repo.update!()
		end
	end

	test "rejects DELETE", %{log: log} do
		assert_raise Postgrex.Error, ~r/append-only/, fn -> Repo.delete!(log) end
	end
end

test "control row is removed with its resource" do
	res = Factory.insert!(:economic_resource)
	agent = Factory.insert!(:person)
	%{resource_id: res.id, controller_id: agent.id, source: :admin}
	|> ResourceControl.changeset()
	|> Repo.insert!(on_conflict: :nothing, conflict_target: :resource_id)

	# Detach the raise event created by the factory so the FK from
	# vf_economic_event doesn't block deleting the resource; the thing
	# under test is the zf_resource_control cascade, not event history.
	from(e in Zenflows.VF.EconomicEvent, where: e.resource_inventoried_as_id == ^res.id)
	|> Repo.update_all(set: [resource_inventoried_as_id: nil])

	Repo.delete!(res)
	assert Repo.get_by(ResourceControl, resource_id: res.id) == nil
end
end
