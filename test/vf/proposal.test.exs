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

defmodule ZenflowsTest.VF.Proposal do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Proposal

setup do
	%{params: %{
		name: Factory.str("name"),
		has_beginning: DateTime.utc_now(),
		has_end: DateTime.utc_now(),
		unit_based: Factory.bool(),
		note: Factory.str("note"),
		eligible_location_id: Factory.build(:spatial_thing).id,
	}}
end

test "create Proposal", %{params: params} do
	assert {:ok, %Proposal{} = prop} =
		params
		|> Proposal.changeset()
		|> Repo.insert()

	assert prop.name == params.name
	assert prop.has_beginning == params.has_beginning
	assert prop.has_end == params.has_end
	assert prop.unit_based == params.unit_based
	assert prop.note == params.note
	assert prop.eligible_location_id == params.eligible_location_id
end

test "update Proposal", %{params: params} do
	assert {:ok, %Proposal{} = prop} =
		:proposal
		|> Factory.insert!()
		|> Proposal.changeset(params)
		|> Repo.update()

	assert prop.name == params.name
	assert prop.has_beginning == params.has_beginning
	assert prop.has_end == params.has_end
	assert prop.unit_based == params.unit_based
	assert prop.note == params.note
	assert prop.eligible_location_id == params.eligible_location_id
end
end
