defmodule ZenflowsTest.Valflow.Person.Domain do
use ZenflowsTest.Case.Repo, async: true

alias Ecto.Changeset
alias Zenflows.Valflow.{Person, Person.Domain}

setup ctx do
	params = %{
		name: Factory.uniq("name"),
		image: Factory.uri(),
		note: Factory.uniq("note"),
		primary_location_id: Factory.insert!(:spatial_thing).id,
		user: Factory.uniq("user"),
		email: Factory.uniq("email"),
		pass_plain: Factory.pass_plain(),
	}

	if ctx[:no_insert] do
		%{params: params}
	else
		%{params: params, per: Factory.insert!(:person)}
	end
end

describe "by_id/1" do
	test "returns a Person", %{per: per}  do
		assert %Person{type: :per} = Domain.by_id(per.id)
	end

	test "doesn't return an Organization" do
		org = Factory.insert!(:organization)

		assert Domain.by_id(org.id) == nil
	end
end

@tag :no_insert
test "all/0 returns all Persons" do
	want_ids =
		Enum.map(1..10, fn _ -> Factory.insert!(:person).id end)
		|> Enum.sort()
	have_ids =
		Domain.all()
		|> Enum.map(& &1.id)
		|> Enum.sort()

	assert have_ids == want_ids
end

describe "create/1" do
	test "creates a Person with valid params", %{params: params} do
		assert {:ok, %Person{} = per} = Domain.create(params)

		assert per.type == :per
		assert per.name == params.name
		assert per.note == params.note
		assert per.image == params.image
		assert per.primary_location_id == params.primary_location_id
		assert per.user == params.user
		assert per.email == params.email
		assert per.pass == Factory.pass()
	end

	test "doesn't create a Person with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a Person with valid params", %{params: params, per: old} do
		assert {:ok, %Person{} = new} = Domain.update(old.id, params)

		assert new.name == params.name
		assert new.note == params.note
		assert new.image == params.image
		assert new.primary_location_id == params.primary_location_id
		assert new.user == params.user
		assert new.email == old.email
		assert new.pass == Factory.pass()
	end

	test "doesn't update a Person with invalid params", %{per: old} do
		assert {:ok, %Person{} = new} =
			Domain.update(old.id, %{email: "can't change that yet"})

		assert new.name == old.name
		assert new.note == old.note
		assert new.image == nil # old.image
		assert new.primary_location_id == old.primary_location_id
		assert new.user == old.user
		assert new.email == old.email
		assert new.pass == Factory.pass()
	end
end

test "delete/1 deletes a Person", %{per: %{id: id}} do
	assert {:ok, %Person{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
