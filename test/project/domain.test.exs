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

defmodule ZenflowsTest.VF.EconomicEvent do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.Project.Domain
alias Zenflows.Wallet

setup_all do
	[errmsg_exist_xnor: "exactly one of them must be provided"]
end

describe "`onCreate` flow" do
	setup do
		agent = Factory.insert!(:agent)
		contributor = Factory.insert!(:agent)
		title = "Test project"
		%{params: %{
			agent: agent,
			contributor: contributor,
			title: title,
		}}
	end

	test "create a project and add a contributor", %{params: params} do
		{:ok, coins_before} = Wallet.get_points_amount(params.agent.id, :idea)

		create_params = %{
			title: params.title,
			description: "ciccio",
			link: "example.com",
			tags: ["aa", "bbb"],
			location_name: "ciccio",
			location: %{
				lat: 13,
				lng: 42,
				address: "Main way"
			},
			location_remote: true,
			images: [],
			licenses: [],
			relations: [],
			project_type: "design",
			contributors: [],
			declarations: [],
			owner_id: params.agent.id,
		}
		{:ok, evt} = Domain.create(create_params)
		evt = evt
			|> Repo.preload(:output_of)
			|> Repo.preload(:resource_inventoried_as)

		assert String.contains?(evt.output_of.name, params.title)
		assert evt.resource_inventoried_as.name == params.title

		contribute_params = %{
			contributor_id: params.contributor.id,
			process_id: evt.output_of.id,
			user: params.agent,
		}
		{:ok, coins_after} = Wallet.get_points_amount(params.agent.id, :idea)
		assert coins_after - coins_before == 100
		{:ok, _} = Domain.add_contributor(contribute_params)
	end

end

end
