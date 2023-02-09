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

defmodule ZenflowsTest.VF.Process.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"name" => Factory.str("name"),
			"note" => Factory.str("note"),
			"hasBeginning" => Factory.iso_now(),
			"hasEnd" => Factory.iso_now(),
			"finished" => Factory.bool(),
			"classifiedAs" => Factory.str_list("class"),
			"basedOn" => Factory.insert!(:process_specification).id,
			"plannedWithin" => Factory.insert!(:plan).id,
			"nestedIn" => Factory.insert!(:scenario).id,
		},
		inserted: Factory.insert!(:process),
	}
end

@frag """
fragment process on Process {
	id
	name
	note
	hasBeginning
	hasEnd
	finished
	deletable
	classifiedAs
	basedOn {id}
	plannedWithin {id}
	nestedIn {id}
}
"""

describe "Query" do
	test "process", %{inserted: new} do
		assert %{data: %{"process" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					process(id: $id) {...process}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["name"] == new.name
		assert data["hasBeginning"] == DateTime.to_iso8601(new.has_beginning)
		assert data["hasEnd"] == DateTime.to_iso8601(new.has_end)
		assert data["finished"] == new.finished
		assert data["deletable"] == false
		assert data["classifiedAs"] == new.classified_as
		assert data["basedOn"]["id"] == new.based_on_id
		assert data["plannedWithin"]["id"] == new.planned_within_id
		assert data["nestedIn"]["id"] == new.nested_in_id
	end
end

describe "Mutation" do
	test "createProcess", %{params: params} do
		assert %{data: %{"createProcess" => %{"process" => data}}} =
			run!("""
				#{@frag}
				mutation ($process: ProcessCreateParams!) {
					createProcess(process: $process) {
						process {...process}
					}
				}
			""", vars: %{"process" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])

		keys = ~w[name hasBeginning hasEnd finished classifiedAs]
		assert Map.take(data, keys) == Map.take(params, keys)

		assert data["deletable"] == false
		assert data["basedOn"]["id"] == params["basedOn"]
		assert data["plannedWithin"]["id"] == params["plannedWithin"]
		assert data["nestedIn"]["id"] == params["nestedIn"]
	end

	test "updateProcess", %{params: params, inserted: old} do
		assert %{data: %{"updateProcess" => %{"process" => data}}} =
			run!("""
				#{@frag}
				mutation ($process: ProcessUpdateParams!) {
					updateProcess(process: $process) {
						process {...process}
					}
				}
			""", vars: %{"process" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		keys = ~w[name hasBeginning hasEnd finished classifiedAs]
		assert Map.take(data, keys) == Map.take(params, keys)

		assert data["deletable"] == false
		assert data["basedOn"]["id"] == params["basedOn"]
		assert data["plannedWithin"]["id"] == params["plannedWithin"]
		assert data["nestedIn"]["id"] == params["nestedIn"]
	end

	test "deleteProcess", %{inserted: %{id: id}} do
		assert %{data: %{"deleteProcess" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteProcess(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
