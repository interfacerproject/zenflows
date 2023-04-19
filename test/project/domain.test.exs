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
alias Zenflows.VF.EconomicEvent
alias Zenflows.Wallet

test "create a project and add a contributor" do
	owner = Factory.insert!(:agent)

	assert {:ok, amount} = Wallet.get_idea_points(owner.id)
	assert Decimal.eq?(amount, Decimal.new("0"))
	create_params = %{
		title: Factory.str("title"),
		description: Factory.str("description"),
		link: Factory.uri(),
		tags: Factory.str_list("tags"),
		location_name: Factory.str("location_name"),
		location: %{
			lat: Factory.decimal(),
			lng: Factory.decimal(),
			address: Factory.str("address"),
		},
		location_remote: Factory.bool(),
		images: [],
		licenses: [],
		relations: [],
		project_type: :design,
		contributors: [],
		declarations: [],
		owner_id: owner.id,
	}
	assert {:ok, create_evt} = Domain.create(create_params)
	create_evt = create_evt
		|> EconomicEvent.Domain.preload(:output_of)
		|> EconomicEvent.Domain.preload(:resource_inventoried_as)
	assert create_evt.output_of.name == "creation of #{create_params.title} by #{owner.name}"
	assert create_evt.resource_inventoried_as.name == create_params.title
	assert {:ok, amount} = Wallet.get_idea_points(owner.id)
	assert Decimal.eq?(amount, Decimal.new("100"))

	contributor = Factory.insert!(:agent)
	contribute_params = %{
		contributor_id: contributor.id,
		process_id: create_evt.output_of_id,
		owner_id: owner.id,
	}
	assert {:ok, _} = Domain.add_contributor(contribute_params)
	assert {:ok, amount} = Wallet.get_idea_points(owner.id)
	assert Decimal.eq?(amount, Decimal.new("200"))

	fork_params = %{
		resource_id: create_evt.resource_inventoried_as_id,
		description: Factory.str("description"),
		contribution_repository: "",
		owner_id: owner.id,
	}
	assert {:ok, result} = Domain.fork(fork_params)
	forking_evt = EconomicEvent.Domain.preload(result.forking_evt, :resource_inventoried_as)
	assert forking_evt.resource_inventoried_as.name
		== "#{create_evt.resource_inventoried_as.name} resource forked by #{owner.name}"
	assert {:ok, amount} = Wallet.get_idea_points(owner.id)
	assert Decimal.eq?(amount, Decimal.new("300"))

	cite_params = %{
		resource_id: forking_evt.resource_inventoried_as_id,
		process_id: forking_evt.output_of_id,
		owner_id: owner.id,
	}
	assert {:ok, _} = Domain.cite(cite_params)
	assert {:ok, amount} = Wallet.get_idea_points(owner.id)
	assert Decimal.eq?(amount, Decimal.new("400"))

	accept_params = %{
		proposal_id: Factory.insert!(:proposal).id,
		owner_id: owner.id,
	}
	assert {:ok, _} = Domain.approve(accept_params)
	assert {:ok, amount} = Wallet.get_idea_points(owner.id)
	assert Decimal.eq?(amount, Decimal.new("400"))
end
end
