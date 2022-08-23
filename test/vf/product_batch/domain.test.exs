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

defmodule ZenflowsTest.VF.ProductBatch.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{ProductBatch, ProductBatch.Domain}

setup do
	%{
		params: %{
			batch_number: Factory.uniq("batch number"),
			expiry_date: DateTime.utc_now(),
			production_date: DateTime.utc_now(),
		},
		inserted: Factory.insert!(:product_batch),
	}
end

describe "one/1" do
	test "with good id: finds the ProductBatch", %{inserted: %{id: id}} do
		assert {:ok, %ProductBatch{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the ProductBatch" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a ProductBatch", %{params: params} do
		assert {:ok, %ProductBatch{} = new} = Domain.create(params)
		assert new.batch_number == params.batch_number
		assert new.expiry_date == params.expiry_date
		assert new.production_date == params.production_date
	end

	test "with bad params: doesn't create a ProductBatch" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the ProductBatch", %{params: params, inserted: old} do
		assert {:ok, %ProductBatch{} = new} = Domain.update(old.id, params)
		assert new.batch_number == params.batch_number
		assert new.expiry_date == params.expiry_date
		assert new.production_date == params.production_date
	end

	test "with bad params: doesn't update the ProductBatch", %{inserted: old} do
		assert {:ok, %ProductBatch{} = new} = Domain.update(old.id, %{})
		assert new.batch_number == old.batch_number
		assert new.expiry_date == old.expiry_date
		assert new.production_date == old.production_date
	end
end

describe "delete/1" do
	test "with good id: deletes the ProductBatch", %{inserted: %{id: id}} do
		assert {:ok, %ProductBatch{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the ProductBatch" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end
end
