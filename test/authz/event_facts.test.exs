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

defmodule ZenflowsTest.Authz.EventFacts do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.Authz.{EventFacts, ResourceControl}
alias Zenflows.VF.EconomicEvent

setup do
	alice = Factory.insert!(:person)
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	raise! = fn ->
		EconomicEvent.Domain.create!(Factory.ctx(alice), %{
			action_id: "raise", provider_id: alice.id, receiver_id: alice.id,
			resource_conforms_to_id: spec.id,
			resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
			has_point_in_time: Factory.now(),
		}, %{name: Factory.str("r")}).resource_inventoried_as_id
	end
	%{alice: alice, r1: raise!.(), r2: raise!.()}
end

test "load/3 collects resources, controls, contents and admin rows", c do
	org = Factory.insert!(:organization)
	Factory.insert_admin!(c.alice, org)
	Repo.update_all(from(r in Zenflows.VF.EconomicResource, where: r.id == ^c.r2),
		set: [contained_in_id: c.r1])
	Repo.update_all(from(x in ResourceControl, where: x.resource_id == ^c.r1),
		set: [controller_id: org.id])

	f = EventFacts.load(Repo, Factory.ctx(c.alice), %{
		action_id: "transfer", provider_id: c.alice.id, receiver_id: c.alice.id,
		resource_inventoried_as_id: c.r1,
	})

	assert f.action == "transfer" and f.source_id == c.r1
	assert f.touched.changes == [c.r1] and f.touched.creates == :destination
	assert f.contained == %{c.r1 => [c.r2]}
	assert Map.keys(f.controls) |> Enum.sort() == Enum.sort([c.r1, c.r2])
	assert Map.has_key?(f.resources, c.r1) and Map.has_key?(f.resources, c.r2)
	assert MapSet.member?(f.admin_of, org.id)
end

test "for_event/3 loads the event and its agents' admin rows", c do
	evt = Repo.one!(from e in EconomicEvent, where: e.resource_inventoried_as_id == ^c.r1, limit: 1)
	assert %EventFacts{event: %EconomicEvent{id: id}} = EventFacts.for_event(Repo, Factory.ctx(c.alice), evt.id)
	assert id == evt.id
	assert %EventFacts{event: nil} = EventFacts.for_event(Repo, Factory.ctx(c.alice), Factory.id())
end

test "load/3 for a cite-shaped event locks the referenced resource but no controls", c do
	f = EventFacts.load(Repo, Factory.ctx(c.alice), %{
		action_id: "cite", provider_id: c.alice.id, receiver_id: c.alice.id,
		resource_inventoried_as_id: c.r1,
	})

	assert f.touched.changes == [] and f.touched.references == [c.r1]
	assert Map.has_key?(f.resources, c.r1)
	assert f.controls == %{}
end

test "load/3 admin_of excludes organizations unrelated to the event's agents", c do
	org = Factory.insert!(:organization)
	Factory.insert_admin!(c.alice, org)

	f = EventFacts.load(Repo, Factory.ctx(c.alice), %{
		action_id: "cite", provider_id: c.alice.id, receiver_id: c.alice.id,
		resource_inventoried_as_id: c.r1,
	})

	refute MapSet.member?(f.admin_of, org.id)
end
end
