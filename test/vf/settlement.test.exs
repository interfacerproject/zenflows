# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule ZenflowsTest.VF.Settlement do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Settlement

setup do
	%{params: %{
		note: Factory.str("note"),
		settled_by_id: Factory.insert!(:economic_event).id,
		settles_id: Factory.insert!(:claim).id,
		resource_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
		effort_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
	}}
end

@tag skip: "TODO: fix events in factory"
test "create Settlement", %{params: params} do
	assert {:ok, %Settlement{} = settl} =
		params
		|> Settlement.changeset()
		|> Repo.insert()

	assert settl.note == params.note
	assert settl.settled_by_id == params.settled_by_id
	assert settl.settles_id == params.settles_id
	assert settl.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert settl.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert settl.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert settl.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
end

@tag skip: "TODO: fix events in factory"
test "update Settlement", %{params: params} do
	assert {:ok, %Settlement{} = settl} =
		:settlement
		|> Factory.insert!()
		|> Settlement.changeset(params)
		|> Repo.update()

	assert settl.note == params.note
	assert settl.settled_by_id == params.settled_by_id
	assert settl.settles_id == params.settles_id
	assert settl.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert settl.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert settl.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert settl.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
end
end
