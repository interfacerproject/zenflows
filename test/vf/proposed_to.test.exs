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

defmodule ZenflowsTest.VF.ProposedTo do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.ProposedTo

setup do
	%{params: %{
		proposed_to_id: Factory.insert!(:agent).id,
		proposed_id: Factory.insert!(:proposal).id,
	}}
end

test "create ProposedTo", %{params: params} do
	assert {:ok, %ProposedTo{} = prop_to} =
		params
		|> ProposedTo.chgset()
		|> Repo.insert()

	assert prop_to.proposed_to_id == params.proposed_to_id
	assert prop_to.proposed_id == params.proposed_id
end

test "update ProposedTo", %{params: params} do
	assert {:ok, %ProposedTo{} = prop_to} =
		:proposed_to
		|> Factory.insert!()
		|> ProposedTo.chgset(params)
		|> Repo.update()

	assert prop_to.proposed_to_id == params.proposed_to_id
	assert prop_to.proposed_id == params.proposed_id
end
end
