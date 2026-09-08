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

defmodule ZenflowsTest.VF.EconomicResource.FilterScoping do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.DB.Page
alias Zenflows.VF.EconomicResource.Domain

# Create an EconomicResource with a controllable name / note / conforms_to /
# classified_as, mirroring the geo_search test's approach.
defp insert_resource!(opts) do
	spec_id = opts[:conforms_to_id] || Factory.insert!(:resource_specification).id
	agent = Factory.insert!(:agent)
	%{resource_inventoried_as_id: res_id} =
		Zenflows.VF.EconomicEvent.Domain.create!(%{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_classified_as: opts[:classified_as] || Factory.str_list("uri"),
			resource_conforms_to_id: spec_id,
			resource_quantity: %{
				has_numerical_value: Factory.decimald(),
				has_unit_id: Factory.insert!(:unit).id,
			},
			has_point_in_time: Factory.now(),
		}, %{name: opts[:name] || Factory.str("name"), note: opts[:note] || Factory.str("note")})
	Domain.one!(res_id)
end

defp result_ids(filter) do
	{:ok, results} = Domain.all(Page.new(%{filter: filter}))
	MapSet.new(results, & &1.id)
end

describe "or_name / or_note are ANDed with the other filters (not a top-level OR)" do
	test "a name match under the wrong conforms_to is excluded" do
		spec_a = Factory.insert!(:resource_specification).id
		spec_b = Factory.insert!(:resource_specification).id

		match      = insert_resource!(conforms_to_id: spec_a, name: "solar charger mk1")
		wrong_spec = insert_resource!(conforms_to_id: spec_b, name: "solar charger mk2")

		ids = result_ids(%{conforms_to: [spec_a], or_name: "solar", or_note: "solar"})

		assert MapSet.member?(ids, match.id),
			"resource matching both conforms_to and or_name must be returned"
		refute MapSet.member?(ids, wrong_spec.id),
			"resource matching or_name but NOT conforms_to must be excluded"
	end

	test "a note match under the wrong conforms_to is excluded; a note match under the right one is included" do
		spec_a = Factory.insert!(:resource_specification).id
		spec_b = Factory.insert!(:resource_specification).id

		note_match  = insert_resource!(conforms_to_id: spec_a, name: "unrelated", note: "great for solar charger repair")
		wrong_spec  = insert_resource!(conforms_to_id: spec_b, name: "unrelated", note: "solar charger")

		ids = result_ids(%{conforms_to: [spec_a], or_name: "solar", or_note: "solar"})

		assert MapSet.member?(ids, note_match.id)
		refute MapSet.member?(ids, wrong_spec.id)
	end

	test "the or_name/or_note pair still behaves as an OR internally" do
		spec = Factory.insert!(:resource_specification).id

		by_name = insert_resource!(conforms_to_id: spec, name: "solar kit",   note: "nothing here")
		by_note = insert_resource!(conforms_to_id: spec, name: "nothing here", note: "a charger")
		neither = insert_resource!(conforms_to_id: spec, name: "nothing here", note: "nothing here")

		ids = result_ids(%{conforms_to: [spec], or_name: "solar", or_note: "charger"})

		assert MapSet.member?(ids, by_name.id)
		assert MapSet.member?(ids, by_note.id)
		refute MapSet.member?(ids, neither.id)
	end

	test "not_custodian still applies when combined with or_name" do
		spec = Factory.insert!(:resource_specification).id
		excluded_custodian = insert_resource!(conforms_to_id: spec, name: "solar excluded")
		# the resource's custodian is its provider agent; reuse that id as the excluded one
		excluded_id = Zenflows.VF.EconomicResource.Domain.one!(excluded_custodian.id).custodian_id

		kept = insert_resource!(conforms_to_id: spec, name: "solar kept")

		ids = result_ids(%{
			conforms_to: [spec],
			not_custodian: [excluded_id],
			or_name: "solar",
			or_note: "solar",
		})

		assert MapSet.member?(ids, kept.id)
		refute MapSet.member?(ids, excluded_custodian.id),
			"not_custodian must still exclude, even with or_name present"
	end
end
end
