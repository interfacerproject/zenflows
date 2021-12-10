defmodule ZenflowsTest.Valflow.RoleBehavior.Type do
use ZenflowsTest.Case.Absin, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		role_behavior: Factory.insert!(:role_behavior),
	}
end

describe "Query" do
	test "roleBehavior()", %{role_behavior: role_beh} do
		assert %{data: %{"roleBehavior" => data}} =
			query!("""
				roleBehavior(id: "#{role_beh.id}") {
					id
					name
					note
				}
			""")

		assert data["id"] == role_beh.id
		assert data["name"] == role_beh.name
		assert data["note"] == role_beh.note
	end
end

describe "Mutation" do
	test "createRoleBehavior()", %{params: params} do
		assert %{data: %{"createRoleBehavior" => %{"roleBehavior" => data}}} =
			mutation!("""
				createRoleBehavior(roleBehavior: {
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					roleBehavior {
						id
						name
						note
					}
				}
			""")

		assert {:ok, _} = Zenflows.Ecto.Id.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
	end

	test "updateRoleBehavior()", %{params: params, role_behavior: role_beh} do
		assert %{data: %{"updateRoleBehavior" => %{"roleBehavior" => data}}} =
			mutation!("""
				updateRoleBehavior(roleBehavior: {
					id: "#{role_beh.id}"
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					roleBehavior {
						id
						name
						note
					}
				}
			""")

		assert data["id"] == role_beh.id
		assert data["name"] == params.name
		assert data["note"] == params.note
	end

	test "deleteRoleBehavior()", %{role_behavior: %{id: id}} do
		assert %{data: %{"deleteRoleBehavior" => true}} =
			mutation!("""
				deleteRoleBehavior(id: "#{id}")
			""")
	end
end
end
