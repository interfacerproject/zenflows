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

defmodule ZenflowsTest.VF.Person.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Person, Person.Domain}

setup ctx do
	params = %{
		name: Factory.uniq("name"),
		image: Factory.uri(),
		note: Factory.uniq("note"),
		primary_location_id: Factory.insert!(:spatial_thing).id,
		user: Factory.uniq("user"),
		email: "#{Factory.uniq("user")}@example.com",
		dilithium_public_key: Base.url_encode64("dilithium_public_key"),
		ecdh_public_key: Base.url_encode64("ecdh_public_key"),
		eddsa_public_key: Base.url_encode64("eddsa_public_key"),
		ethereum_address: Base.url_encode64("ethereum_address"),
		reflow_public_key: Base.url_encode64("reflow_public_key"),
		schnorr_public_key: Base.url_encode64("schnorr_public_key"),
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
		assert per.dilithium_public_key == params.dilithium_public_key
		assert per.ecdh_public_key == params.ecdh_public_key
		assert per.eddsa_public_key == params.eddsa_public_key
		assert per.ethereum_address == params.ethereum_address
		assert per.reflow_public_key == params.reflow_public_key
		assert per.schnorr_public_key == params.schnorr_public_key
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
		assert new.dilithium_public_key == old.dilithium_public_key
		assert new.ecdh_public_key == old.ecdh_public_key
		assert new.eddsa_public_key == old.eddsa_public_key
		assert new.ethereum_address == old.ethereum_address
		assert new.reflow_public_key == old.reflow_public_key
		assert new.schnorr_public_key == old.schnorr_public_key
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
		assert new.dilithium_public_key == old.dilithium_public_key
		assert new.ecdh_public_key == old.ecdh_public_key
		assert new.eddsa_public_key == old.eddsa_public_key
		assert new.ethereum_address == old.ethereum_address
		assert new.reflow_public_key == old.reflow_public_key
		assert new.schnorr_public_key == old.schnorr_public_key
	end
end

test "delete/1 deletes a Person", %{per: %{id: id}} do
	assert {:ok, %Person{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
