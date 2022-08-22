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

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			image: Factory.img(),
			note: Factory.uniq("note"),
			primary_location_id: Factory.insert!(:spatial_thing).id,
			user: Factory.uniq("user"),
			email: "#{Factory.uniq("user")}@example.com",
			ecdh_public_key: Base.encode64("ecdh_public_key"),
			eddsa_public_key: Base.encode64("eddsa_public_key"),
			ethereum_address: Base.encode64("ethereum_address"),
			reflow_public_key: Base.encode64("reflow_public_key"),
			schnorr_public_key: Base.encode64("schnorr_public_key"),
		},
		inserted: Factory.insert!(:person),
	}
end

describe "one/1" do
	test "with good id: finds the Person", %{inserted: %{id: id}} do
		assert {:ok, %Person{}} = Domain.one(id)
	end

	test "with org's id: doesn't return an Organization" do
		org = Factory.insert!(:organization)
		assert {:error, "not found"} = Domain.one(org.id)
	end

	test "with bad id: doesn't find the Person" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a Person", %{params: params} do
		assert {:ok, %Person{} = new} = Domain.create(params)
		assert new.type == :per
		assert new.name == params.name
		assert new.note == params.note
		assert new.image == params.image
		assert new.primary_location_id == params.primary_location_id
		assert new.user == params.user
		assert new.email == params.email
		assert new.ecdh_public_key == params.ecdh_public_key
		assert new.eddsa_public_key == params.eddsa_public_key
		assert new.ethereum_address == params.ethereum_address
		assert new.reflow_public_key == params.reflow_public_key
		assert new.schnorr_public_key == params.schnorr_public_key
	end

	test "with bad params: doesn't create a Person" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the Person", %{params: params, inserted: old} do
		assert {:ok, %Person{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.image == params.image
		assert new.primary_location_id == params.primary_location_id
		assert new.user == params.user
		assert new.email == old.email
		assert new.ecdh_public_key == old.ecdh_public_key
		assert new.eddsa_public_key == old.eddsa_public_key
		assert new.ethereum_address == old.ethereum_address
		assert new.reflow_public_key == old.reflow_public_key
		assert new.schnorr_public_key == old.schnorr_public_key
	end

	test "with bad params: doesn't update the Person", %{inserted: old} do
		assert {:ok, %Person{} = new} = Domain.update(old.id, %{email: "can't change that yet"})
		assert new.name == old.name
		assert new.note == old.note
		assert new.image == old.image
		assert new.primary_location_id == old.primary_location_id
		assert new.user == old.user
		assert new.email == old.email
		assert new.ecdh_public_key == old.ecdh_public_key
		assert new.eddsa_public_key == old.eddsa_public_key
		assert new.ethereum_address == old.ethereum_address
		assert new.reflow_public_key == old.reflow_public_key
		assert new.schnorr_public_key == old.schnorr_public_key
	end
end

describe "delete/1" do
	test "with good id: deletes the Person", %{inserted: %{id: id}} do
		assert {:ok, %Person{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the Person" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end
end
