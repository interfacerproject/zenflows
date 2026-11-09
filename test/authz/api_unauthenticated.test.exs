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

defmodule ZenflowsTest.Authz.APIUnauthenticated do
use ZenflowsTest.Help.AbsinCase, async: false

alias Zenflows.VF.{EconomicEvent, EconomicResource}

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

	prev = Application.get_env(:zenflows, Zenflows.Authz)
	Application.put_env(:zenflows, Zenflows.Authz, enforce: true, allow_unchecked: false)
	on_exit(fn ->
		if prev,
			do: Application.put_env(:zenflows, Zenflows.Authz, prev),
			else: Application.delete_env(:zenflows, Zenflows.Authz)
	end)

	%{res_id: evt.resource_inventoried_as_id}
end

test "an unsigned updateEconomicResource is UNAUTHENTICATED with data null", %{res_id: id} do
	assert %{data: nil, errors: [err]} =
		run!("""
			mutation ($id: ID!) {
				updateEconomicResource(resource: {id: $id, name: "anon's"}) { economicResource { id } }
			}
		""", vars: %{"id" => id})
	assert Map.take(err, [:message, :extensions]) ==
		%{message: "unauthenticated", extensions: %{code: "UNAUTHENTICATED"}}
	assert err.path == ["updateEconomicResource"]
	assert EconomicResource.Domain.one!(id).name == "alice's"
end
end
