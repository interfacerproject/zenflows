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

defmodule ZenflowsTest.VF.Unit.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			"label" => Factory.uniq("label"),
			"symbol" => Factory.uniq("symbol"),
		},
		inserted: Factory.insert!(:unit),
	}
end

@frag """
fragment unit on Unit {
	id
	label
	symbol
}
"""

describe "Query" do
	test "unit", %{inserted: new} do
		assert %{data: %{"unit" => data}} =
			run!("""
				#{@frag}
				query ($id: ID!) {
					unit(id: $id) {...unit}
				}
			""", vars: %{"id" => new.id})

		assert data["id"] == new.id
		assert data["label"] == new.label
		assert data["symbol"] == new.symbol
	end
end

describe "Mutation" do
	test "createUnit", %{params: params} do
		assert %{data: %{"createUnit" => %{"unit" => data}}} =
			run!("""
				#{@frag}
				mutation ($unit: UnitCreateParams!) {
					createUnit(unit: $unit) {
						unit {...unit}
					}
				}
			""", vars: %{"unit" => params})

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["label"] == params["label"]
		assert data["symbol"] == params["symbol"]
	end

	test "updateUnit", %{params: params, inserted: old} do
		assert %{data: %{"updateUnit" => %{"unit" => data}}} =
			run!("""
				#{@frag}
				mutation ($unit: UnitUpdateParams!) {
					updateUnit(unit: $unit) {
						unit {...unit}
					}
				}
			""", vars: %{"unit" => Map.put(params, "id", old.id)})

		assert data["id"] == old.id
		assert data["label"] == params["label"]
		assert data["symbol"] == params["symbol"]
	end

	test "deleteUnit", %{inserted: %{id: id}} do
		assert %{data: %{"deleteUnit" => true}} =
			run!("""
				mutation ($id: ID!) {
					deleteUnit(id: $id)
				}
			""", vars: %{"id" => id})
	end
end
end
