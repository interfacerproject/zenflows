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

defmodule ZenflowsTest.Authz.ResourceControl do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Zenflows.Authz.{ExecutionContext, PermissionLog, ResourceControl}
alias Zenflows.VF.EconomicEvent

setup do
	%{
		alice: Factory.insert!(:person),
		bob: Factory.insert!(:person),
		carol: Factory.insert!(:person),
		org: Factory.insert!(:organization),
		unit: Factory.insert!(:unit),
		spec: Factory.insert!(:resource_specification),
	}
end

defp raise!(ctx, receiver_id, c) do
	EconomicEvent.Domain.create!(ctx, %{
		action_id: "raise",
		provider_id: receiver_id,
		receiver_id: receiver_id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: Factory.str("res")})
end

defp control(evt), do: Repo.get_by!(ResourceControl, resource_id: evt.resource_inventoried_as_id)

defp logs(res_id) do
	Repo.all(from l in PermissionLog, where: l.target_id == ^res_id and l.action == "resource_control.set")
end

test "self-receiver: creator controls, one log row", c do
	evt = raise!(Factory.ctx(c.alice), c.alice.id, c)
	assert %ResourceControl{controller_id: id, source: :creation, epoch: 0} = control(evt)
	assert id == c.alice.id
	assert [%PermissionLog{actor_id: actor, service: :gql, subject_id: subject}] =
		logs(evt.resource_inventoried_as_id)
	assert actor == c.alice.id and subject == c.alice.id
end

test "foreign receiver: verified creator controls; declared receiver recorded", c do
	evt = raise!(Factory.ctx(c.bob), c.alice.id, c)
	assert control(evt).controller_id == c.bob.id
	assert [%PermissionLog{after: %{"declared_receiver_id" => declared}}] =
		logs(evt.resource_inventoried_as_id)
	assert declared == c.alice.id
end

test "org receiver: org controls when the creator is its admin", c do
	Factory.insert_admin!(c.alice, c.org)
	evt = raise!(Factory.ctx(c.alice), c.org.id, c)
	assert control(evt).controller_id == c.org.id
end

test "org receiver: creator controls when not an admin", c do
	evt = raise!(Factory.ctx(c.bob), c.org.id, c)
	assert control(evt).controller_id == c.bob.id
end

test "transfer to another agent: new resource controlled by the creator", c do
	evt = raise!(Factory.ctx(c.bob), c.bob.id, c)
	transfer = EconomicEvent.Domain.create!(Factory.ctx(c.bob), %{
		action_id: "transfer",
		provider_id: c.bob.id,
		receiver_id: c.carol.id,
		resource_inventoried_as_id: evt.resource_inventoried_as_id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	})
	assert %ResourceControl{controller_id: id} =
		Repo.get_by!(ResourceControl, resource_id: transfer.to_resource_inventoried_as_id)
	assert id == c.bob.id
end

test "migration context creates no control row", c do
	evt = raise!(ExecutionContext.service(:migration, nil), c.alice.id, c)
	assert Repo.get_by(ResourceControl, resource_id: evt.resource_inventoried_as_id) == nil
end

test "anonymous (unchecked) context: primary accountable controls", c do
	evt = raise!(Factory.ctx(), c.alice.id, c)
	assert %ResourceControl{controller_id: id, source: :creation} = control(evt)
	assert id == c.alice.id
end

test "create/3 rejects a missing context" do
	assert_raise FunctionClauseError, fn ->
		EconomicEvent.Domain.create(%{action_id: "raise"}, nil)
	end
end
end
