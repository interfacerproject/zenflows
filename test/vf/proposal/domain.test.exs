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

defmodule ZenflowsTest.VF.Proposal.Domain do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.{
	Proposal,
	Proposal.Domain,
	SpatialThing,
}

setup do
	%{
		params: %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			has_beginning: Factory.now(),
			has_end: Factory.now(),
			unit_based: Factory.bool(),
			eligible_location_id: Factory.insert!(:spatial_thing).id,
		},
		inserted: Factory.insert!(:proposal),
	}
end

describe "one/1" do
	test "with good id: finds the Proposal", %{inserted: %{id: id}} do
		assert {:ok, %Proposal{}} = Domain.one(id)
	end

	test "with bad id: doesn't find the Proposal" do
		assert {:error, "not found"} = Domain.one(Factory.id())
	end
end

describe "create/1" do
	test "with good params: creates a Proposal", %{params: params} do
		assert {:ok, %Proposal{} = new} = Domain.create(params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.has_beginning == params.has_beginning
		assert new.has_end == params.has_end
		assert new.unit_based == params.unit_based
		assert new.eligible_location_id == params.eligible_location_id
	end

	test "with empty params: creates a Proposal" do
		assert {:ok, %Proposal{} = new} = Domain.create(%{})
		assert new.name == nil
		assert new.note == nil
		assert new.has_beginning == nil
		assert new.has_end == nil
		assert new.unit_based == false # since it defaults
		assert new.eligible_location_id == nil
	end
end

describe "update/2" do
	test "with good params: updates the Proposal", %{params: params, inserted: old} do
		assert {:ok, %Proposal{} = new} = Domain.update(old.id, params)
		assert new.name == params.name
		assert new.note == params.note
		assert new.has_beginning == params.has_beginning
		assert new.has_end == params.has_end
		assert new.unit_based == params.unit_based
		assert new.eligible_location_id == params.eligible_location_id
	end

	test "with bad params: doesn't update the Proposal", %{inserted: old} do
		assert {:ok, %Proposal{} = new} = Domain.update(old.id, %{})
		assert new.name == old.name
		assert new.note == old.note
		assert new.has_beginning == old.has_beginning
		assert new.has_end == old.has_end
		assert new.unit_based == old.unit_based
		assert new.eligible_location_id == old.eligible_location_id
	end
end

describe "delete/1" do
	test "with good id: deletes the Proposal", %{inserted: %{id: id}} do
		assert {:ok, %Proposal{id: ^id}} = Domain.delete(id)
		assert {:error, "not found"} = Domain.one(id)
	end

	test "with bad id: doesn't delete the Proposal" do
		assert {:error, "not found"} = Domain.delete(Factory.id())
	end
end

describe "preload/2" do
	test "preloads `:eligible_location`", %{inserted: %{id: id}} do
		assert {:ok, prop} =  Domain.one(id)
		prop = Domain.preload(prop, :eligible_location)
		assert %SpatialThing{} = prop.eligible_location
 	end

	test "preloads `:publishes`", %{inserted: %{id: id}} do
		assert {:ok, prop} =  Domain.one(id)

		assert [] = Domain.preload(prop, :publishes).publishes

		left =
			Enum.map(0..9, fn _ ->
				Factory.insert!(:proposed_intent, %{published_in: prop}).id
			end)
		right =
			Domain.preload(prop, :publishes)
			|> Map.fetch!(:publishes)
			|> Enum.map(& &1.id)
		assert left -- right == []
 	end

	test "preloads `:primary_intents`", %{inserted: %{id: id}} do
		assert {:ok, prop} =  Domain.one(id)

		assert [] = Domain.preload(prop, :primary_intents).primary_intents

		left =
			Enum.map(0..9, fn _ ->
				Factory.insert!(:proposed_intent, %{published_in: prop, reciprocal: false}).publishes_id
			end)
		right =
			Domain.preload(prop, :primary_intents)
			|> Map.fetch!(:primary_intents)
			|> Enum.map(& &1.id)
		assert left -- right == []
 	end

	test "preloads `:reciprocal_intents`", %{inserted: %{id: id}} do
		assert {:ok, prop} =  Domain.one(id)

		assert [] = Domain.preload(prop, :reciprocal_intents).reciprocal_intents

		left =
			Enum.map(0..9, fn _ ->
				Factory.insert!(:proposed_intent, %{published_in: prop, reciprocal: true}).publishes_id
			end)
		right =
			Domain.preload(prop, :reciprocal_intents)
			|> Map.fetch!(:reciprocal_intents)
			|> Enum.map(& &1.id)
		assert left -- right == []
 	end
end
end
