defmodule ZenflowsTest.VF.Unit.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			label: Factory.uniq("label"),
			symbol: Factory.uniq("symbol"),
		},
		unit: Factory.insert!(:unit),
	}
end

describe "Query" do
	test "unit()", %{unit: unit} do
		assert %{data: %{"unit" => data}} =
			query!("""
				unit(id: "#{unit.id}") {
					id
					label
					symbol
				}
			""")

		assert data["id"] == unit.id
		assert data["label"] == unit.label
		assert data["symbol"] == unit.symbol
	end
end

describe "Mutation" do
	test "createUnit()", %{params: params} do
		assert %{data: %{"createUnit" => %{"unit" => data}}} =
			mutation!("""
				createUnit(unit: {
					label: "#{params.label}"
					symbol: "#{params.symbol}"
				}) {
					unit {
						id
						label
						symbol
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["label"] == params.label
		assert data["symbol"] == params.symbol
	end

	test "updateUnit()", %{params: params, unit: unit} do
		assert %{data: %{"updateUnit" => %{"unit" => data}}} =
			mutation!("""
				updateUnit(unit: {
					id: "#{unit.id}"
					label: "#{params.label}"
					symbol: "#{params.symbol}"
				}) {
					unit {
						id
						label
						symbol
					}
				}
			""")

		assert data["id"] == unit.id
		assert data["label"] == params.label
		assert data["symbol"] == params.symbol
	end

	test "deleteUnit()", %{unit: %{id: id}} do
		assert %{data: %{"deleteUnit" => true}} =
			mutation!("""
				deleteUnit(id: "#{id}")
			""")
	end
end
end
