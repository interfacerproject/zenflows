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

defmodule ZenflowsTest.Authz.EconomicResource do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query
import ZenflowsTest.Help.AbsinCase, only: [run!: 2]

alias Ecto.Changeset
alias Zenflows.Authz.{PermissionLog, ResourceControl}
alias Zenflows.VF.{EconomicEvent, EconomicResource}

setup do
	alice = Factory.insert!(:person)
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	evt = EconomicEvent.Domain.create!(Factory.ctx(alice), %{
		action_id: "raise",
		provider_id: alice.id,
		receiver_id: alice.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: "alice's"})
	%{alice: alice, bob: Factory.insert!(:person), res: EconomicResource.Domain.one!(evt.resource_inventoried_as_id)}
end

test "controller may update", %{alice: alice, res: res} do
	assert {:ok, %EconomicResource{name: "renamed"}} =
		EconomicResource.Domain.update(Factory.ctx(alice), res.id, %{name: "renamed"})
end

test "another person may not update or delete", %{bob: bob, res: res} do
	assert {:error, :forbidden} = EconomicResource.Domain.update(Factory.ctx(bob), res.id, %{name: "x"})
	assert {:error, :forbidden} = EconomicResource.Domain.delete(Factory.ctx(bob), res.id)
	assert EconomicResource.Domain.one!(res.id).name == "alice's"
end

test "admin of the controlling org may update; revoked admin may not", %{bob: bob, res: res} do
	org = Factory.insert!(:organization)
	Repo.update_all(from(c in ResourceControl, where: c.resource_id == ^res.id),
		set: [controller_id: org.id])
	rel = Factory.insert_admin!(bob, org)
	assert {:ok, _} = EconomicResource.Domain.update(Factory.ctx(bob), res.id, %{name: "org's"})

	rel |> Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update!()
	assert {:error, :forbidden} = EconomicResource.Domain.update(Factory.ctx(bob), res.id, %{name: "x"})
end

test "missing id: forbidden for persons, not found for unchecked anonymous", %{bob: bob} do
	assert {:error, :forbidden} = EconomicResource.Domain.update(Factory.ctx(bob), Factory.id(), %{name: "x"})
	assert {:error, "not found"} = EconomicResource.Domain.update(Factory.ctx(), Factory.id(), %{name: "x"})
end

test "no control row: even primaryAccountable is denied", %{alice: alice, res: res} do
	Repo.delete_all(from c in ResourceControl, where: c.resource_id == ^res.id)
	assert {:error, :forbidden} = EconomicResource.Domain.update(Factory.ctx(alice), res.id, %{name: "x"})
end

test "delete by controller removes control and logs it", %{alice: alice, res: res} do
	# Detach the raise event created in setup so the FK from
	# vf_economic_event doesn't block deleting the resource; the thing
	# under test is the authz/control-removal path, not event history.
	from(e in EconomicEvent, where: e.resource_inventoried_as_id == ^res.id)
	|> Repo.update_all(set: [resource_inventoried_as_id: nil])

	assert {:ok, _} = EconomicResource.Domain.delete(Factory.ctx(alice), res.id)
	assert Repo.get_by(ResourceControl, resource_id: res.id) == nil
	assert [%PermissionLog{actor_id: actor}] =
		Repo.all(from l in PermissionLog, where: l.target_id == ^res.id and l.action == "resource_control.remove")
	assert actor == alice.id
end

test "resourceControl query", %{alice: alice, res: res} do
	assert %{data: %{"resourceControl" => %{"controller" => %{"id" => id}, "source" => "creation", "epoch" => 0}}} =
		run!("""
			query ($id: ID!) {
				resourceControl(resourceId: $id) { controller { id } source epoch }
			}
		""", vars: %{"id" => res.id})
	assert id == alice.id
end
end
