defmodule ZenflowsTest.Valflow.ProcessSpecification.Type do
use ZenflowsTest.Case.Absin, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
		},
		process_specification: Factory.insert!(:process_specification),
	}
end

describe "Query" do
	test "processSpecification()", %{process_specification: proc_spec} do
		assert %{data: %{"processSpecification" => data}} =
			query!("""
				processSpecification(id: "#{proc_spec.id}") {
					id
					name
					note
				}
			""")

		assert data["id"] == proc_spec.id
		assert data["name"] == proc_spec.name
		assert data["note"] == proc_spec.note
	end
end

describe "Mutation" do
	test "createProcessSpecification()", %{params: params} do
		assert %{data: %{"createProcessSpecification" => %{"processSpecification" => data}}} =
			mutation!("""
				createProcessSpecification(processSpecification: {
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					processSpecification {
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

	test "updateProcessSpecification()", %{params: params, process_specification: proc_spec} do
		assert %{data: %{"updateProcessSpecification" => %{"processSpecification" => data}}} =
			mutation!("""
				updateProcessSpecification(processSpecification: {
					id: "#{proc_spec.id}"
					name: "#{params.name}"
					note: "#{params.note}"
				}) {
					processSpecification {
						id
						name
						note
					}
				}
			""")

		assert data["id"] == proc_spec.id
		assert data["name"] == params.name
		assert data["note"] == params.note
	end

	test "deleteProcessSpecification()", %{process_specification: %{id: id}} do
		assert %{data: %{"deleteProcessSpecification" => true}} =
			mutation!("""
				deleteProcessSpecification(id: "#{id}")
			""")
	end
end
end
