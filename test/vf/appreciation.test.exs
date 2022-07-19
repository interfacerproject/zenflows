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

defmodule ZenflowsTest.VF.Appreciation do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Appreciation

setup do
	%{params: %{
		appreciation_of_id: Factory.insert!(:economic_event).id,
		appreciation_with_id: Factory.insert!(:economic_event).id,
		note: Factory.uniq("note"),
	}}
end

@tag skip: "TODO: fix events in factory"
test "create Appreciation", %{params: params} do
	assert {:ok, %Appreciation{} = appr} =
		params
		|> Appreciation.chgset()
		|> Repo.insert()

	assert appr.appreciation_of_id == params.appreciation_of_id
	assert appr.appreciation_with_id == params.appreciation_with_id
	assert appr.note == params.note
end

@tag skip: "TODO: fix events in factory"
test "update Appreciation", %{params: params} do
	assert {:ok, %Appreciation{} = appr} =
		:appreciation
		|> Factory.insert!()
		|> Appreciation.chgset(params)
		|> Repo.update()

	assert appr.appreciation_of_id == params.appreciation_of_id
	assert appr.appreciation_with_id == params.appreciation_with_id
	assert appr.note == params.note
end
end
