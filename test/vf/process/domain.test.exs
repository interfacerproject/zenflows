# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule ZenflowsTest.VF.Process.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{
	Plan,
	Process,
	Process.Domain,
	ProcessSpecification,
	Scenario,
}

setup do
	%{
		params: %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
			finished: Factory.bool(),
			classified_as: Factory.str_list("class"),
			based_on_id: Factory.insert!(:process_specification).id,
			planned_within_id: Factory.insert!(:plan).id,
			nested_in_id: Factory.insert!(:scenario).id,
	 	},
		inserted: Factory.insert!(:process),
	}
end

describe "one/1" do
	test "with good id: finds the Process", %{inserted: %{id: id}} do
		assert {:ok, %Process{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the Process" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a Process", %{params: params} do
		assert {:ok, %Process{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.has_beginning == params.has_beginning
		assert new.has_end == params.has_end
		assert new.finished == params.finished
		assert new.classified_as == params.classified_as
		assert new.based_on_id == params.based_on_id
		assert new.planned_within_id == params.planned_within_id
		assert new.nested_in_id == params.nested_in_id
	end

	test "with bad params: doesn't create a Process" do
		assert {:error, %Changeset{}} = Domain.create(%{})
	end
end

describe "update/2" do
	test "with good params: updates the Process", %{params: params, inserted: old} do
		assert {:ok, %Process{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.has_beginning == params.has_beginning
		assert new.has_end == params.has_end
		assert new.finished == params.finished
		assert new.classified_as == params.classified_as
		assert new.based_on_id == params.based_on_id
		assert new.planned_within_id == params.planned_within_id
		assert new.nested_in_id == params.nested_in_id
	end

	test "with bad params: doesn't update the Process", %{inserted: old} do
		assert {:ok, %Process{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.note == old.note
		assert new.has_beginning == old.has_beginning
		assert new.has_end == old.has_end
		assert new.finished == old.finished
		assert new.classified_as == old.classified_as
		assert new.based_on_id == old.based_on_id
		assert new.planned_within_id == old.planned_within_id
		assert new.nested_in_id == old.nested_in_id
	end
end

describe "delete/1" do
	test "with good id: deletes the Process", %{inserted: %{id: id}} do
		assert {:ok, %Process{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the Process" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end

describe "preload/2" do
	test "preloads :based_on", %{inserted: proc} do
		proc = Domain.preload(proc, :based_on)
		assert based_on = %ProcessSpecification{} = proc.based_on
		assert based_on.id == proc.based_on_id
	end

	test "preloads :planned_within", %{inserted: proc} do
		proc = Domain.preload(proc, :planned_within)
		assert planed_within = %Plan{} = proc.planned_within
		assert planed_within.id == proc.planned_within_id
	end

	test "preloads :nested_in", %{inserted: proc} do
		proc = Domain.preload(proc, :nested_in)
		assert nested_in = %Scenario{} = proc.nested_in
		assert nested_in.id == proc.nested_in_id
	end
end
end
