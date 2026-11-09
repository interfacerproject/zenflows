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

defmodule ZenflowsTest.Authz.Events do
use ZenflowsTest.Help.EctoCase, async: false

alias Zenflows.Authz.{PermissionLog, ResourceControl}
alias Zenflows.VF.{EconomicEvent, EconomicResource}

setup do
	prev = Application.get_env(:zenflows, Zenflows.Authz)
	on_exit(fn -> Application.put_env(:zenflows, Zenflows.Authz, prev) end)
	%{
		alice: Factory.insert!(:person),
		bob: Factory.insert!(:person),
		carol: Factory.insert!(:person),
		unit: Factory.insert!(:unit),
		spec: Factory.insert!(:resource_specification),
	}
end

defp raise!(c, signer, agent, attrs \\ %{}) do
	EconomicEvent.Domain.create(Factory.ctx(signer), Map.merge(%{
		action_id: "raise", provider_id: agent.id, receiver_id: agent.id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, attrs), %{name: Factory.str("res")})
end

defp res_of!(c, owner) do
	{:ok, evt} = raise!(c, owner, owner)
	EconomicResource.Domain.one!(evt.resource_inventoried_as_id)
end

defp event(c, signer, attrs, res_params \\ nil) do
	EconomicEvent.Domain.create(Factory.ctx(signer), Map.merge(%{
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, attrs), res_params)
end

defp control(id), do: Repo.get_by(ResourceControl, resource_id: id)

test "Bob cannot raise in Alice's name", c do
	assert {:error, :forbidden} = raise!(c, c.bob, c.alice)
end

test "Bob cannot lower Alice's resource as provider or as receiver", c do
	res = res_of!(c, c.alice)
	assert {:error, :forbidden} =
		event(c, c.bob, %{action_id: "lower", provider_id: c.bob.id, receiver_id: c.bob.id, resource_inventoried_as_id: res.id})
	assert {:error, :forbidden} =
		event(c, c.bob, %{action_id: "lower", provider_id: c.alice.id, receiver_id: c.alice.id, resource_inventoried_as_id: res.id})
	assert Decimal.eq?(EconomicResource.Domain.one!(res.id).onhand_quantity_has_numerical_value, 1)
end

test "Bob cannot pull Alice's resource to himself", c do
	res = res_of!(c, c.alice)
	assert {:error, :forbidden} =
		event(c, c.bob, %{action_id: "transfer", provider_id: c.alice.id, receiver_id: c.bob.id,
			resource_inventoried_as_id: res.id}, %{name: "stolen"})
	assert EconomicResource.Domain.one!(res.id).primary_accountable_id == c.alice.id
end

test "Bob may cite Alice's resource in his own event", c do
	res = res_of!(c, c.alice)
	assert {:ok, %EconomicEvent{}} =
		event(c, c.bob, %{action_id: "cite", input_of_id: Factory.insert!(:process).id,
			provider_id: c.bob.id, receiver_id: c.bob.id, resource_inventoried_as_id: res.id})
end

test "transfer gives control of the new resource to the receiver, logged with event_id", c do
	res = res_of!(c, c.alice)
	{:ok, evt} = event(c, c.alice, %{action_id: "transfer", provider_id: c.alice.id,
		receiver_id: c.carol.id, resource_inventoried_as_id: res.id}, %{name: "gift"})
	assert %ResourceControl{controller_id: cid} = control(evt.to_resource_inventoried_as_id)
	assert cid == c.carol.id
	evt_id = evt.id
	assert [%PermissionLog{after: %{"event_id" => ^evt_id}}] =
		Repo.all(from l in PermissionLog, where: l.target_id == ^evt.to_resource_inventoried_as_id
			and l.action == "resource_control.set")
end

test "admin of the controlling org may act; a revoked admin may not", c do
	org = Factory.insert!(:organization)
	rel = Factory.insert_admin!(c.alice, org)
	{:ok, evt} = raise!(c, c.alice, org)
	res_id = evt.resource_inventoried_as_id
	assert control(res_id).controller_id == org.id
	assert {:ok, _} = event(c, c.alice, %{action_id: "lower", provider_id: org.id,
		receiver_id: org.id, resource_quantity: %{has_numerical_value: "0.5", has_unit_id: c.unit.id},
		resource_inventoried_as_id: res_id})
	rel |> Ecto.Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update!()
	assert {:error, :forbidden} = event(c, c.alice, %{action_id: "lower", provider_id: org.id,
		receiver_id: org.id, resource_quantity: %{has_numerical_value: "0.5", has_unit_id: c.unit.id},
		resource_inventoried_as_id: res_id})
end

test "container whose contents someone else controls blocks the transfer", c do
	box = res_of!(c, c.alice)
	item = res_of!(c, c.bob)
	Repo.update_all(from(r in EconomicResource, where: r.id == ^item.id), set: [contained_in_id: box.id])
	assert {:error, :forbidden} =
		event(c, c.alice, %{action_id: "transferCustody", provider_id: c.alice.id,
			receiver_id: c.carol.id, resource_inventoried_as_id: box.id}, %{name: "box"})
end

test "combine is denied", c do
	assert {:error, :forbidden} =
		event(c, c.alice, %{action_id: "combine", provider_id: c.alice.id, receiver_id: c.alice.id})
end

test "invalid params still return the changeset error", c do
	assert {:error, %Ecto.Changeset{}} = EconomicEvent.Domain.create(Factory.ctx(c.bob), %{action_id: "raise"})
end

describe "claims" do
	setup c do
		losh = Factory.insert!(:person)
		Application.put_env(:zenflows, Zenflows.Authz,
			Keyword.put(Application.get_env(:zenflows, Zenflows.Authz), :claimable_agents, [losh.id]))
		%{losh: losh, losh_res: res_of!(c, losh)}
	end

	test "anyone may claim to themselves; claimer controls the copy; logged once", c do
		{:ok, evt} = event(c, c.bob, %{action_id: "transfer", provider_id: c.losh.id,
			receiver_id: c.bob.id, resource_inventoried_as_id: c.losh_res.id}, %{name: "mine"})
		assert control(evt.to_resource_inventoried_as_id).controller_id == c.bob.id
		new_id = evt.to_resource_inventoried_as_id
		assert [%PermissionLog{actor_id: actor, target_id: tid, after: %{"resource_id" => ^new_id}}] =
			Repo.all(from l in PermissionLog, where: l.action == "resource.claim")
		assert actor == c.bob.id and tid == c.losh_res.id
	end

	test "claim for someone else, or into an existing resource, is denied", c do
		assert {:error, :forbidden} = event(c, c.bob, %{action_id: "transfer", provider_id: c.losh.id,
			receiver_id: c.carol.id, resource_inventoried_as_id: c.losh_res.id}, %{name: "x"})
		mine = res_of!(c, c.bob)
		assert {:error, :forbidden} = event(c, c.bob, %{action_id: "transfer", provider_id: c.losh.id,
			receiver_id: c.bob.id, resource_inventoried_as_id: c.losh_res.id,
			to_resource_inventoried_as_id: mine.id})
	end

	test "nothing is claimable with an empty list", c do
		Application.put_env(:zenflows, Zenflows.Authz,
			Keyword.put(Application.get_env(:zenflows, Zenflows.Authz), :claimable_agents, []))
		assert {:error, :forbidden} = event(c, c.bob, %{action_id: "transfer", provider_id: c.losh.id,
			receiver_id: c.bob.id, resource_inventoried_as_id: c.losh_res.id}, %{name: "x"})
	end
end
end
