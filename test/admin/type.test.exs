defmodule ZenflowsTest.Admin.Type do
use ZenflowsTest.Help.AbsinCase, async: true

setup do
	%{
		params: %{
			admin_key: Application.fetch_env!(:zenflows, Zenflows.Admin)[:admin_key] |> Base.encode16(case: :lower),
			name: Factory.str("name"),
			pass: Factory.pass_plain(),
			email: "#{Factory.str("name")}@example.com",
			user: Factory.str("user"),
			pubkeys_encoded: Base.url_encode64(Jason.encode!(%{foobar: 1, barfoo: 2})),
		},
	}
end

test "createUser()", %{params: params} do
	assert %{data: %{"createUser" => data}} =
		mutation!("""
			createUser(
				adminKey: "#{params.admin_key}"
				name: "#{params.name}"
				pass: "#{params.pass}"
				email: "#{params.email}"
				user: "#{params.user}"
				pubkeys: "#{params.pubkeys_encoded}"
			) {
				id
				name
				user
				email
				pubkeys
			}
		""")

	assert {:ok, _} = Zenflows.DB.ID.cast(data["id"])
	assert data["name"] == params.name
	assert data["email"] == params.email
	assert data["name"] == params.name
	assert data["user"] == params.user
	assert data["pubkeys"] == params.pubkeys_encoded
end
end
