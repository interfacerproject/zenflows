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

defmodule ZenflowsTest.VF.Agent.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.Agent.Domain

setup do
		%{
			per: Factory.insert!(:person),
			org: Factory.insert!(:organization),
		}
end

describe "one/1" do
	test "with per's id: finds the Person", %{per: per} do
		assert {:ok, agent} = Domain.one(per.id)

		# common
		assert agent.id == per.id
		assert agent.type == per.type and agent.type == :per
		assert agent.name == per.name
		assert agent.note == per.note
		assert agent.primary_location_id == per.primary_location_id

		# person
		assert agent.user == per.user
		assert agent.email == per.email

		# organization
		assert agent.classified_as == nil
	end

	test "with org's id: finds the Organization", %{org: org} do
		assert {:ok, agent} = Domain.one(org.id)

		# common
		assert agent.id == org.id
		assert agent.type == org.type and agent.type == :org
		assert agent.name == org.name
		assert agent.note == org.note
		assert agent.primary_location_id == org.primary_location_id

		# person
		assert agent.user == nil
		assert agent.email == nil

		# organization
		assert agent.classified_as == org.classified_as
	end
end

describe "preload/2" do
	test "preloads :primary_location for a Person", %{per: per} do
		{:ok, agent} = Domain.one(per.id)
		agent = Domain.preload(agent, :primary_location)
		assert agent.primary_location.id == agent.primary_location_id
	end

	test "preloads :primary_location for an Organization", %{org: org} do
		{:ok, agent} = Domain.one(org.id)
		agent = Domain.preload(agent, :primary_location)
		assert agent.primary_location.id == agent.primary_location_id
	end
end
end
