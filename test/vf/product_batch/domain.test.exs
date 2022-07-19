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

test "by_id/1 returns a ProductBatch", %{inserted: batch} do
	assert %ProductBatch{} = Domain.by_id(batch.id)
end

describe "create/1" do
	test "creates a ProductBatch with valid params", %{params: params} do
		assert {:ok, %ProductBatch{} = batch} = Domain.create(params)

		assert batch.batch_number == params.batch_number
		assert batch.expiry_date == params.expiry_date
		assert batch.production_date == params.production_date
	end

	test "doesn't create a ProductBatch with invalid params" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "updates a ProductBatch with valid params", %{params: params, inserted: old} do
		assert {:ok, %ProductBatch{} = new} = Domain.update(old.id, params)

		assert new.batch_number == params.batch_number
		assert new.expiry_date == params.expiry_date
		assert new.production_date == params.production_date
	end

	test "doesn't update a ProductBatch", %{inserted: old} do
		assert {:ok, %ProductBatch{} = new} = Domain.update(old.id, %{})

		assert new.batch_number == old.batch_number
		assert new.expiry_date == old.expiry_date
		assert new.production_date == old.production_date
	end
end

test "delete/1 deletes a ProductBatch", %{inserted: %{id: id}} do
	assert {:ok, %ProductBatch{id: ^id}} = Domain.delete(id)
	assert Domain.by_id(id) == nil
end
end
