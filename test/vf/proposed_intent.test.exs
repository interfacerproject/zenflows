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

defmodule ZenflowsTest.VF.ProposedIntent do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.ProposedIntent

setup do
	%{params: %{
		reciprocal: Factory.bool(),
		publishes_id: Factory.insert!(:intent).id,
		published_in_id: Factory.insert!(:proposal).id,
	}}
end

test "create ProposedIntent", %{params: params} do
	assert {:ok, %ProposedIntent{} = prop_int} =
		params
		|> ProposedIntent.chgset()
		|> Repo.insert()

	assert prop_int.reciprocal == params.reciprocal
	assert prop_int.publishes_id == params.publishes_id
	assert prop_int.published_in_id == params.published_in_id
end

test "update ProposedIntent", %{params: params} do
	assert {:ok, %ProposedIntent{} = prop_int} =
		:proposed_intent
		|> Factory.insert!()
		|> ProposedIntent.chgset(params)
		|> Repo.update()

	assert prop_int.reciprocal == params.reciprocal
	assert prop_int.publishes_id == params.publishes_id
	assert prop_int.published_in_id == params.published_in_id
end
end
