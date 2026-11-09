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

defmodule ZenflowsTest.Authz.Person do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Zenflows.Authz.{ExecutionContext, PermissionLog}
alias Zenflows.VF.Person

defp admin_ctx(),
	do: ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})

setup do
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person)}
end

test "self may update; others may not", %{alice: alice, bob: bob} do
	assert {:ok, %Person{name: "Alice"}} = Person.Domain.update(Factory.ctx(alice), alice.id, %{name: "Alice"})
	assert {:error, :forbidden} = Person.Domain.update(Factory.ctx(bob), alice.id, %{name: "x"})
end

test "persons cannot create or delete persons", %{alice: alice, bob: bob} do
	assert {:error, :forbidden} =
		Person.Domain.create(Factory.ctx(alice), %{name: "n", user: "u", email: "u@example.com"})
	assert {:error, :forbidden} = Person.Domain.delete(Factory.ctx(alice), bob.id)
end

test "admin key create/delete are logged" do
	{:ok, per} = Person.Domain.create(admin_ctx(), %{name: Factory.str("n"), user: Factory.str("u"), email: "#{Factory.str("u")}@example.com"})
	{:ok, _} = Person.Domain.delete(admin_ctx(), per.id)
	assert ["person.create", "person.delete"] ==
		Repo.all(from l in PermissionLog, where: l.target_id == ^per.id, select: l.action)
		|> Enum.sort()
end

test "person controlling resources cannot be deleted", %{alice: alice} do
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	Zenflows.VF.EconomicEvent.Domain.create!(Factory.ctx(alice), %{
		action_id: "raise", provider_id: alice.id, receiver_id: alice.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: "r"})
	assert {:error, "agent controls resources; it cannot be deleted"} =
		Person.Domain.delete(admin_ctx(), alice.id)
end
end
