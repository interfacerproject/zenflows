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

defmodule ZenflowsTest.VF.Scenario.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Scenario,
	Scenario.Domain,
	ScenarioDefinition,
}

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
			defined_as_id: Factory.insert!(:scenario_definition).id,
			refinement_of_id: Factory.insert!(:scenario).id,
	 	},
		inserted: Factory.insert!(:scenario),
	}
end

describe "one/1" do
	test "with good id: finds the Scenario", %{inserted: %{id: id}} do
		assert {:ok, %Scenario{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the Scenario" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a Scenario", %{params: params} do
		assert {:ok, %Scenario{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.has_beginning == params.has_beginning
		assert new.has_end == params.has_end
		assert new.defined_as_id == params.defined_as_id
		assert new.refinement_of_id == params.refinement_of_id
	end

	test "with bad params: doesn't create a Scenario" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the Scenario", %{params: params, inserted: old} do
		assert {:ok, %Scenario{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.has_beginning == params.has_beginning
		assert new.has_end == params.has_end
		assert new.defined_as_id == params.defined_as_id
		assert new.refinement_of_id == params.refinement_of_id
	end

	test "with bad params: doesn't update the Scenario", %{inserted: old} do
		assert {:ok, %Scenario{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.note == old.note
		assert new.has_beginning == old.has_beginning
		assert new.has_end == old.has_end
		assert new.defined_as_id == old.defined_as_id
		assert new.refinement_of_id == old.refinement_of_id
	end
end

describe "delete/1" do
	test "with good id: deletes the Scenario", %{inserted: %{id: id}} do
		assert {:ok, %Scenario{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the Scenario" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end

describe "preload/2" do
	test "preloads `:defined_as`", %{inserted: scen} do
		scen = Domain.preload(scen, :defined_as)
		assert scen_def = %ScenarioDefinition{} = scen.defined_as
		assert scen_def.id == scen.defined_as_id
	end

	test "preloads `:refinement_of`", %{inserted: scen} do
		scen = Domain.preload(scen, :refinement_of)
		# since it has 50% chance
		if scen.refinement_of != nil do
			assert refin_of = %Scenario{} = scen.refinement_of
			assert refin_of.id == scen.refinement_of_id
		end
	end
end
end
