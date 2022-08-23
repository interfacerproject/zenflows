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

defmodule ZenflowsTest.VF.ProposedIntent.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Intent,
	Proposal,
	ProposedIntent,
	ProposedIntent.Domain,
}

setup do
	%{
		params: %{
			reciprocal: Factory.bool(),
			publishes_id: Factory.insert!(:intent).id,
			published_in_id: Factory.insert!(:proposal).id,
		},
		inserted: Factory.insert!(:proposed_intent),
	}
end

describe "one/1" do
	test "with good id: finds the ProposedIntent", %{inserted: %{id: id}} do
		assert {:ok, %ProposedIntent{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the ProposedIntent" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a ProposedIntent", %{params: params} do
		assert {:ok, %ProposedIntent{} = new} = Domain.create(params)
		assert new.reciprocal == params.reciprocal
		assert new.publishes_id == params.publishes_id
		assert new.published_in_id == params.published_in_id
	end

	test "with bad params: doesn't create a ProposedIntent" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "delete/1" do
	test "with good id: deletes the ProposedIntent", %{inserted: %{id: id}} do
		assert {:ok, %ProposedIntent{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the ProposedIntent" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end

describe "preload/2" do
	test "preloads `:published_in`", %{inserted: %{id: id}} do
		assert {:ok, prop} =  Domain.one(id)
		prop = Domain.preload(prop, :published_in)
		assert %Proposal{} = prop.published_in
 	end

	test "preloads `:publishes`", %{inserted: %{id: id}} do
		assert {:ok, prop} =  Domain.one(id)
		prop = Domain.preload(prop, :publishes)
		assert %Intent{} = prop.publishes
 	end
end
end
