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

defmodule ZenflowsTest.VF.Claim do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Claim

setup do
	%{params: %{
		action_id: Factory.build(:action_id),
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		resource_classified_as: Factory.str_list("uri"),
		resource_conforms_to_id: Factory.insert!(:resource_specification).id,
		resource_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
		effort_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.float(),
		},
		triggered_by_id: Factory.insert!(:economic_event).id,
		due: Factory.now(),
		finished: Factory.bool(),
		note: Factory.str("note"),
		agreed_in: Factory.str("uri"),
		# in_scope_of_id:
	}}
end

@tag skip: "TODO: fix events in factory"
test "create Claim", %{params: params} do
	assert {:ok, %Claim{} = claim} =
		params
		|> Claim.chgset()
		|> Repo.insert()

	assert claim.action_id == params.action_id
	assert claim.provider_id == params.provider_id
	assert claim.receiver_id == params.receiver_id
	assert claim.resource_classified_as == params.resource_classified_as
	assert claim.resource_conforms_to_id == params.resource_conforms_to_id
	assert claim.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert claim.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert claim.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert claim.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	assert claim.triggered_by_id == params.triggered_by_id
	assert claim.due == params.due
	assert claim.finished == params.finished
	assert claim.note == params.note
	assert claim.agreed_in == params.agreed_in
	# assert in_scope_of
end

@tag skip: "TODO: fix events in factory"
test "update Appreciation", %{params: params} do
	assert {:ok, %Claim{} = claim} =
		:claim
		|> Factory.insert!()
		|> Claim.chgset(params)
		|> Repo.update()

	assert claim.action_id == params.action_id
	assert claim.provider_id == params.provider_id
	assert claim.receiver_id == params.receiver_id
	assert claim.resource_classified_as == params.resource_classified_as
	assert claim.resource_conforms_to_id == params.resource_conforms_to_id
	assert claim.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	assert claim.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	assert claim.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	assert claim.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	assert claim.triggered_by_id == params.triggered_by_id
	assert claim.due == params.due
	assert claim.finished == params.finished
	assert claim.note == params.note
	assert claim.agreed_in == params.agreed_in
	# assert in_scope_of
end
end
