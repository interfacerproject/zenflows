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

defmodule ZenflowsTest.Authz.Satisfactions do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.{EconomicEvent, Intent, Satisfaction}

setup do
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person), carol: Factory.insert!(:person)}
end

# Minimal valid Intent params: `action_id` plus exactly one of
# `provider_id`/`receiver_id` (the changeset requires exactly one).
defp iparams(overrides), do: Map.merge(%{action_id: Factory.build(:action_id)}, overrides)

# An EconomicEvent between `provider` and `receiver`.  Built with the
# anonymous context, which `allow_unchecked` lets through in tests: no
# authorization is needed for this fixture.
defp event!(provider, receiver) do
	EconomicEvent.Domain.create!(Factory.ctx(), %{
		action_id: "deliverService",
		provider_id: provider.id,
		receiver_id: receiver.id,
		resource_conforms_to_id: Factory.insert!(:resource_specification).id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: Factory.insert!(:unit).id},
		has_point_in_time: Factory.now(),
	})
end

test "event (provider Bob, receiver Alice) satisfying an intent whose provider is Bob: Alice may create", c do
	event = event!(c.bob, c.alice)
	{:ok, int} = Intent.Domain.create(Factory.ctx(), iparams(%{provider_id: c.bob.id}))
	assert {:ok, %Satisfaction{}} =
		Satisfaction.Domain.create(Factory.ctx(c.alice),
			%{satisfies_id: int.id, satisfied_by_event_id: event.id})
end

test "same event/intent: Carol may not create the satisfaction", c do
	event = event!(c.bob, c.alice)
	{:ok, int} = Intent.Domain.create(Factory.ctx(), iparams(%{provider_id: c.bob.id}))
	assert {:error, :forbidden} =
		Satisfaction.Domain.create(Factory.ctx(c.carol),
			%{satisfies_id: int.id, satisfied_by_event_id: event.id})
end

test "an intent whose parties don't include Bob or Alice: forbidden for Alice", c do
	event = event!(c.bob, c.alice)
	{:ok, int} = Intent.Domain.create(Factory.ctx(), iparams(%{provider_id: c.carol.id}))
	assert {:error, :forbidden} =
		Satisfaction.Domain.create(Factory.ctx(c.alice),
			%{satisfies_id: int.id, satisfied_by_event_id: event.id})
end

test "satisfied_by_commitment_id only: forbidden, for any person", c do
	commitment = Factory.insert!(:commitment)
	{:ok, int} = Intent.Domain.create(Factory.ctx(), iparams(%{provider_id: c.bob.id}))
	assert {:error, :forbidden} =
		Satisfaction.Domain.create(Factory.ctx(c.bob),
			%{satisfies_id: int.id, satisfied_by_commitment_id: commitment.id})
	assert {:error, :forbidden} =
		Satisfaction.Domain.create(Factory.ctx(c.alice),
			%{satisfies_id: int.id, satisfied_by_commitment_id: commitment.id})
end

describe "update/delete" do
	setup c do
		event = event!(c.bob, c.alice)
		{:ok, int} = Intent.Domain.create(Factory.ctx(), iparams(%{provider_id: c.bob.id}))
		{:ok, satis} = Satisfaction.Domain.create(Factory.ctx(),
			%{satisfies_id: int.id, satisfied_by_event_id: event.id})
		%{satis: satis, event: event}
	end

	# The changeset's own exist_xor validation only counts a field as
	# "present" when it actually changes, so re-pointing to a second
	# event between the same two parties is what exercises a plain,
	# non-structural update here.
	test "update by a party of the event: ok", c do
		other_event = event!(c.bob, c.alice)
		assert {:ok, %Satisfaction{note: "x"}} =
			Satisfaction.Domain.update(Factory.ctx(c.alice), c.satis.id,
				%{note: "x", satisfied_by_event_id: other_event.id})
	end

	test "update by Carol: forbidden", c do
		assert {:error, :forbidden} =
			Satisfaction.Domain.update(Factory.ctx(c.carol), c.satis.id,
				%{note: "x", satisfied_by_event_id: c.event.id})
	end

	test "delete by a party of the event: ok", c do
		assert {:ok, %Satisfaction{}} = Satisfaction.Domain.delete(Factory.ctx(c.bob), c.satis.id)
	end

	test "delete by Carol: forbidden", c do
		assert {:error, :forbidden} = Satisfaction.Domain.delete(Factory.ctx(c.carol), c.satis.id)
	end
end
end
