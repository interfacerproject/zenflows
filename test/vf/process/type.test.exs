defmodule ZenflowsTest.VF.Process.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
			finished: Factory.bool(),
			classified_as: Factory.uniq_list("class"),
			based_on_id: Factory.insert!(:process_specification).id,
			planned_within_id: Factory.insert!(:plan).id,
			nested_in_id: Factory.insert!(:scenario).id,
		},
		process: Factory.insert!(:process),
	}
end

describe "Query" do
	test "process()", %{process: proc} do
		assert %{data: %{"process" => data}} =
			query!("""
				process(id: "#{proc.id}") {
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
			""")

		assert data["id"] == proc.id
		assert data["name"] == proc.name
		assert data["hasBeginning"] == DateTime.to_iso8601(proc.has_beginning)
		assert data["hasEnd"] == DateTime.to_iso8601(proc.has_end)
		assert data["finished"] == proc.finished
		assert data["deletable"] == false
		assert data["classifiedAs"] == proc.classified_as
		assert data["basedOn"]["id"] == proc.based_on_id
		assert data["plannedWithin"]["id"] == proc.planned_within_id
		assert data["nestedIn"]["id"] == proc.nested_in_id
	end
end

describe "Mutation" do
	test "createProcess()", %{params: params} do
		assert %{data: %{"createProcess" => %{"process" => data}}} =
			mutation!("""
				createProcess(process: {
					name: "#{params.name}"
					note: "#{params.note}"
					hasBeginning: "#{params.has_beginning}"
					hasEnd: "#{params.has_end}"
					finished: #{params.finished}
					classifiedAs: #{inspect(params.classified_as)}
					basedOn: "#{params.based_on_id}"
					plannedWithin: "#{params.planned_within_id}"
					nestedIn: "#{params.nested_in_id}"
				}) {
					process {
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
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["hasBeginning"] == DateTime.to_iso8601(params.has_beginning)
		assert data["hasEnd"] == DateTime.to_iso8601(params.has_end)
		assert data["finished"] == params.finished
		assert data["deletable"] == false
		assert data["classifiedAs"] == params.classified_as
		assert data["basedOn"]["id"] == params.based_on_id
		assert data["plannedWithin"]["id"] == params.planned_within_id
		assert data["nestedIn"]["id"] == params.nested_in_id
	end

	test "updateProcess()", %{params: params, process: proc} do
		assert %{data: %{"updateProcess" => %{"process" => data}}} =
			mutation!("""
				updateProcess(process: {
					id: "#{proc.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					hasBeginning: "#{params.has_beginning}"
					hasEnd: "#{params.has_end}"
					finished: #{params.finished}
					classifiedAs: #{inspect(params.classified_as)}
					basedOn: "#{params.based_on_id}"
					plannedWithin: "#{params.planned_within_id}"
					nestedIn: "#{params.nested_in_id}"
				}) {
					process {
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
				}
			""")

		assert data["id"] == proc.id
		assert data["name"] == params.name
		assert data["hasBeginning"] == DateTime.to_iso8601(params.has_beginning)
		assert data["hasEnd"] == DateTime.to_iso8601(params.has_end)
		assert data["finished"] == params.finished
		assert data["deletable"] == false
		assert data["classifiedAs"] == params.classified_as
		assert data["basedOn"]["id"] == params.based_on_id
		assert data["plannedWithin"]["id"] == params.planned_within_id
		assert data["nestedIn"]["id"] == params.nested_in_id
	end

	test "deleteProcess()", %{process: %{id: id}} do
		assert %{data: %{"deleteProcess" => true}} =
			mutation!("""
				deleteProcess(id: "#{id}")
			""")
	end
end
end
