# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

defmodule ZenflowsTest.VF.Fulfillment do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Fulfillment

setup do
	%{params: %{
		note: Factory.str("note"),
		fulfilled_by_id: Factory.insert!(:economic_event).id,
		fulfills_id: Factory.insert!(:commitment).id,
		resource_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.decimal(),
		},
		effort_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.decimal(),
		},
	}}
end

@tag skip: "TODO: fix events in factory"
test "create Fulfillment", %{params: params} do
	assert {:ok, %Fulfillment{} = fulf} =
		params
		|> Fulfillment.changeset()
		|> Repo.insert()

	assert fulf.note == params.note
	assert fulf.fulfilled_by_id == params.fulfilled_by_id
	assert fulf.fulfills_id == params.fulfills_id
	assert fulf.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert fulf.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert fulf.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert fulf.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
end

@tag skip: "TODO: fix events in factory"
test "update Fulfillment", %{params: params} do
	assert {:ok, %Fulfillment{} = fulf} =
		:fulfillment
		|> Factory.insert!()
		|> Fulfillment.changeset(params)
		|> Repo.update()

	assert fulf.note == params.note
	assert fulf.fulfilled_by_id == params.fulfilled_by_id
	assert fulf.fulfills_id == params.fulfills_id
	assert fulf.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert fulf.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert fulf.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert fulf.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
end
end
