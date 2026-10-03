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

defmodule ZenflowsTest.Authz.LogContent do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Zenflows.Authz.{ExecutionContext, PermissionLog, Roles}
alias Zenflows.VF.{AgentRelationship, EconomicEvent, EconomicResource, Person}

@allowed_keys ~w[object_id revoked_at controller_id source epoch declared_receiver_id event_id resource_id target_type]

defp admin_ctx(),
	do: ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})

test "permission log rows hold only the allowed before/after keys and no public keys" do
	before_ids = Repo.all(from l in PermissionLog, select: l.id)

	alice_key = Base.encode64("alice's distinctive eddsa_public_key")
	alice = Factory.insert!(:person, %{eddsa_public_key: alice_key})
	bob = Factory.insert!(:person)
	org = Factory.insert!(:organization)
	Factory.insert_admin!(alice, org)

	# grant, then revoke
	{:ok, rel} = AgentRelationship.Domain.create(Factory.ctx(alice), %{
		subject_id: bob.id,
		object_id: org.id,
		relationship_id: Roles.id!(Repo, "org.admin"),
	})
	{:ok, _} = AgentRelationship.Domain.delete(Factory.ctx(alice), rel.id)

	# resource creation, then delete
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	evt = EconomicEvent.Domain.create!(Factory.ctx(alice), %{
		action_id: "raise", provider_id: alice.id, receiver_id: alice.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: "alice's"})
	res_id = evt.resource_inventoried_as_id
	from(e in EconomicEvent, where: e.resource_inventoried_as_id == ^res_id)
	|> Repo.update_all(set: [resource_inventoried_as_id: nil])
	{:ok, _} = EconomicResource.Domain.delete(Factory.ctx(alice), res_id)

	# person create/delete with the admin key
	per_key = Base.encode64("the created person's eddsa_public_key")
	{:ok, per} = Person.Domain.create(admin_ctx(), %{
		name: Factory.str("n"), user: Factory.str("u"),
		email: "#{Factory.str("u")}@example.com", eddsa_public_key: per_key,
	})
	{:ok, _} = Person.Domain.delete(admin_ctx(), per.id)

	rows = Repo.all(from l in PermissionLog, where: l.id not in ^before_ids)
	assert rows |> Enum.map(& &1.action) |> Enum.sort() == Enum.sort(~w[
		relationship.grant relationship.revoke
		resource_control.set resource_control.remove
		person.create person.delete
	])

	for row <- rows do
		keys = Map.keys(row.before || %{}) ++ Map.keys(row.after || %{})
		assert Enum.reject(keys, &(&1 in @allowed_keys)) == [],
			"#{row.action} logs unexpected keys: #{inspect(keys)}"

		dumped = row |> Map.from_struct() |> Map.delete(:__meta__) |> inspect(limit: :infinity)
		for key <- [alice_key, per_key] do
			refute String.contains?(dumped, key), "#{row.action} logs a public key"
		end
	end
end
end
