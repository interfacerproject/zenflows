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

defmodule ZenflowsTest.VF.ScenarioDefinition.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Duration,
	ScenarioDefinition,
	ScenarioDefinition.Domain,
}

setup do
	%{
		params: %{
			name: Factory.uniq("name"),
			note: Factory.uniq("note"),
			has_duration: Factory.build(:iduration),
	 	},
		inserted: Factory.insert!(:scenario_definition),
	}
end

describe "one/1" do
	test "with good id: finds the ScenarioDefinition", %{inserted: %{id: id}} do
		assert {:ok, %ScenarioDefinition{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the ScenarioDefinition" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a ScenarioDefinition", %{params: params} do
		assert {:ok, %ScenarioDefinition{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.has_duration_unit_type == params.has_duration.unit_type
		assert new.has_duration_numeric_duration == params.has_duration.numeric_duration
	end

	test "with bad params: doesn't create a ScenarioDefinition" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the ScenarioDefinition", %{params: params, inserted: old} do
		assert {:ok, %ScenarioDefinition{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.has_duration_unit_type == params.has_duration.unit_type
		assert new.has_duration_numeric_duration == params.has_duration.numeric_duration
	end

	test "with bad params: doesn't update the ScenarioDefinition", %{inserted: old} do
		assert {:ok, %ScenarioDefinition{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.note == old.note
		assert new.has_duration_unit_type == old.has_duration_unit_type
		assert new.has_duration_numeric_duration == old.has_duration_numeric_duration
	end
end

describe "delete/1" do
	test "with good id: deletes the ScenarioDefinition", %{inserted: %{id: id}} do
		assert {:ok, %ScenarioDefinition{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the ScenarioDefinition" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end

describe "preload/2" do
	test "preloads :has_duration", %{inserted: scen_def} do
		scen_def = Domain.preload(scen_def, :has_duration)
		assert has_dur = %Duration{} = scen_def.has_duration
		assert has_dur.unit_type == scen_def.has_duration_unit_type
		assert has_dur.numeric_duration == scen_def.has_duration_numeric_duration
	end
end
end
