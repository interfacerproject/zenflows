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

defmodule ZenflowsTest.Authz.ResourceControlStrict do
use ZenflowsTest.Help.EctoCase, async: false

alias Zenflows.Authz.ResourceControl
alias Zenflows.VF.{EconomicEvent, EconomicResource}

setup do
	prev = Application.get_env(:zenflows, Zenflows.Authz)
	Application.put_env(:zenflows, Zenflows.Authz, enforce: true, allow_unchecked: false)
	on_exit(fn ->
		if prev,
			do: Application.put_env(:zenflows, Zenflows.Authz, prev),
			else: Application.delete_env(:zenflows, Zenflows.Authz)
	end)

	%{
		alice: Factory.insert!(:person),
		unit: Factory.insert!(:unit),
		spec: Factory.insert!(:resource_specification),
	}
end

test "anonymous raise is refused, not silently granted control, when unchecked is off", c do
	params = %{
		action_id: "raise",
		provider_id: c.alice.id,
		receiver_id: c.alice.id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}

	res_count_before = Repo.aggregate(EconomicResource, :count)
	control_count_before = Repo.aggregate(ResourceControl, :count)

	assert {:error, :unauthenticated} =
		EconomicEvent.Domain.create(Factory.ctx(), params, %{name: "x"})

	# No resource was created under this test's own spec, and the
	# table-wide counts are unchanged: nothing leaked through.
	assert Repo.get_by(EconomicResource, conforms_to_id: c.spec.id) == nil
	assert Repo.aggregate(EconomicResource, :count) == res_count_before
	assert Repo.aggregate(ResourceControl, :count) == control_count_before
end
end
