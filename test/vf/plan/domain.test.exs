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

defmodule ZenflowsTest.VF.Plan.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Plan, Plan.Domain, Scenario}

setup do
	%{
		params: %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			due: Factory.now(),
			refinement_of_id: Factory.insert!(:scenario).id,
	 	},
		inserted: Factory.insert!(:plan),
	 }
end

describe "one/1" do
	test "with good id: finds the Plan", %{inserted: %{id: id}} do
		assert {:ok, %Plan{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the Plan" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a Plan", %{params: params} do
		assert {:ok, %Plan{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.due == params.due
		assert new.refinement_of_id == params.refinement_of_id
	end

	test "with bad params: doesn't create an" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the Plan", %{params: params, inserted: old} do
		assert {:ok, %Plan{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.due == params.due
		assert new.refinement_of_id == params.refinement_of_id
	end

	test "with bad params: doesn't update the Plan", %{inserted: old} do
		assert {:ok, %Plan{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.note == old.note
		assert new.due == old.due
		assert new.refinement_of_id == old.refinement_of_id
	end
end

describe "delete/1" do
	test "with good id: deletes the Plan", %{inserted: %{id: id}} do
		assert {:ok, %Plan{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the Plan" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end

describe "preload/2" do
	test "preloads `:refinement_of`", %{inserted: plan} do
		plan = Domain.preload(plan, :refinement_of)
		assert refin_of = %Scenario{} = plan.refinement_of
		assert refin_of.id == plan.refinement_of_id
	end
end
end
