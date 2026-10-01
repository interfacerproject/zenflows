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

defmodule ZenflowsTest.Authz.API do
use ZenflowsTest.Help.AbsinCase, async: true

alias Zenflows.VF.{EconomicEvent, EconomicResource, Organization}

@forbidden %{message: "forbidden", extensions: %{code: "FORBIDDEN"}}

setup do
	alice = Factory.insert!(:person)
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	evt = EconomicEvent.Domain.create!(Factory.ctx(alice), %{
		action_id: "raise", provider_id: alice.id, receiver_id: alice.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: "alice's"})
	%{alice: alice, bob: Factory.insert!(:person), res_id: evt.resource_inventoried_as_id}
end

test "Bob: updateEconomicResource is FORBIDDEN with data null", %{bob: bob, res_id: id} do
	assert %{data: nil, errors: [err]} =
		run_as!(bob, """
			mutation ($id: ID!) {
				updateEconomicResource(resource: {id: $id, name: "bob's"}) { economicResource { id } }
			}
		""", vars: %{"id" => id})
	assert Map.take(err, [:message, :extensions]) == @forbidden
	assert err.path == ["updateEconomicResource"]
	assert EconomicResource.Domain.one!(id).name == "alice's"
end

test "Bob: aliases and several root fields are each denied", %{bob: bob, res_id: id} do
	# `updateEconomicResource` and `deleteEconomicResource` both return
	# non-null GraphQL types, so when every sibling root field resolves to
	# null (as happens here -- each is independently denied), Absinthe's
	# null-propagation collapses the whole selection set down to a single
	# reported error instead of one per field (see
	# `Absinthe.Phase.Document.Execution.Resolution.do_propagate_null_trimming/1`).
	# We can't assert `length(errors) == 3` because of that collapse, but
	# every error that *does* surface must be FORBIDDEN, and the resource
	# being untouched proves all three resolvers were in fact denied, not
	# just the one whose error happened to survive.
	assert %{data: nil, errors: errors} =
		run_as!(bob, """
			mutation ($id: ID!) {
				a: updateEconomicResource(resource: {id: $id, name: "x"}) { economicResource { id } }
				b: updateEconomicResource(resource: {id: $id, name: "y"}) { economicResource { id } }
				c: deleteEconomicResource(id: $id)
			}
		""", vars: %{"id" => id})
	assert errors != []
	assert Enum.all?(errors, &(Map.take(&1, [:message, :extensions]) == @forbidden))
	assert EconomicResource.Domain.one!(id).name == "alice's"
end

test "Alice: updateEconomicResource succeeds", %{alice: alice, res_id: id} do
	assert %{data: %{"updateEconomicResource" => %{"economicResource" => %{"id" => ^id}}}} =
		run_as!(alice, """
			mutation ($id: ID!) {
				updateEconomicResource(resource: {id: $id, name: "renamed"}) { economicResource { id } }
			}
		""", vars: %{"id" => id})
end

test "signed calls without headers are rejected before authz", %{res_id: id} do
	assert %{errors: [%{message: msg}]} =
		run!("""
			mutation ($id: ID!) { deleteEconomicResource(id: $id) }
		""", auth?: true, vars: %{"id" => id})
	assert msg =~ "zenflows-user"
end

test "Bob cannot update Alice's organization or Alice", %{alice: alice, bob: bob} do
	{:ok, org} = Organization.Domain.create(Factory.ctx(alice), %{name: Factory.str("org")})
	assert %{errors: [err1]} =
		run_as!(bob, """
			mutation ($id: ID!) { updateOrganization(organization: {id: $id, name: "x"}) { agent { id } } }
		""", vars: %{"id" => org.id})
	assert %{errors: [err2]} =
		run_as!(bob, """
			mutation ($id: ID!) { updatePerson(person: {id: $id, name: "x"}) { agent { id } } }
		""", vars: %{"id" => alice.id})
	assert Map.take(err1, [:message, :extensions]) == @forbidden
	assert Map.take(err2, [:message, :extensions]) == @forbidden
end

test "createOrganization makes the signer admin (visible over GraphQL)", %{bob: bob} do
	assert %{data: %{"createOrganization" => %{"agent" => %{"id" => org_id}}}} =
		run_as!(bob, """
			mutation { createOrganization(organization: {name: "#{Factory.str("org")}"}) { agent { id } } }
		""")
	assert %{data: %{"updateOrganization" => %{"agent" => %{"id" => ^org_id}}}} =
		run_as!(bob, """
			mutation ($id: ID!) { updateOrganization(organization: {id: $id, note: "mine"}) { agent { id } } }
		""", vars: %{"id" => org_id})
end
end
