defmodule ZenflowsTest.VF.Agreement.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			created: DateTime.utc_now(),
		},
		agreement: Factory.insert!(:agreement),
	}
end

describe "Query" do
	test "agreement()", %{agreement: agreem} do
		assert %{data: %{"agreement" => data}} =
			query!("""
				agreement(id: "#{agreem.id}") {
					id
					name
					note
					created
				}
			""")

		assert data["id"] == agreem.id
		assert data["name"] == agreem.name
		assert data["note"] == agreem.note
		assert data["created"] == DateTime.to_iso8601(agreem.created)
	end
end

describe "Mutation" do
	test "createAgreement()", %{params: params} do
		assert %{data: %{"createAgreement" => %{"agreement" => data}}} =
			mutation!("""
				createAgreement(agreement: {
					name: "#{params.name}"
					note: "#{params.note}"
					created: "#{params.created}"
				}) {
					agreement {
						id
						name
						note
						created
					}
				}
			""")

		assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["created"] == DateTime.to_iso8601(params.created)
	end

	test "updateAgreement()", %{params: params, agreement: agreem} do
		assert %{data: %{"updateAgreement" => %{"agreement" => data}}} =
			mutation!("""
				updateAgreement(agreement: {
					id: "#{agreem.id}"
					name: "#{params.name}"
					note: "#{params.note}"
					created: "#{params.created}"
				}) {
					agreement {
						id
						name
						note
						created
					}
				}
			""")

		assert data["id"] == agreem.id
		assert data["name"] == params.name
		assert data["note"] == params.note
		assert data["created"] == DateTime.to_iso8601(params.created)
	end

	test "deleteAgreement()", %{agreement: %{id: id}} do
		assert %{data: %{"deleteAgreement" => true}} =
			mutation!("""
				deleteAgreement(id: "#{id}")
			""")
	end
end
end
