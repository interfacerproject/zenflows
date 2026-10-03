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

defmodule ZenflowsTest.Authz.ProcessInvites do
@moduledoc """
Invited-party rule for events: an event may attach to a process the
signer does not control when that process holds an unfinished intent
naming (as provider or receiver) an agent the signer acts for.  This is
how the interfacer-gui accepts a contribution proposal: its
`ACCEPT_PROPOSAL` attaches the owner's events to the proposer's process.
"""
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.{EconomicEvent, Intent, Satisfaction}

setup do
	c = %{
		alice: Factory.insert!(:person),
		bob: Factory.insert!(:person),
		carol: Factory.insert!(:person),
		unit: Factory.insert!(:unit),
		spec: Factory.insert!(:resource_specification),
	}
	Map.merge(c, %{origin: res!(c, c.alice), fork: res!(c, c.bob)})
end

defp res!(c, owner) do
	EconomicEvent.Domain.create!(Factory.ctx(owner), %{
		action_id: "raise", provider_id: owner.id, receiver_id: owner.id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: Factory.str("res")}).resource_inventoried_as_id
end

defp qty(c), do: %{has_numerical_value: "1", has_unit_id: c.unit.id}

# The three intents of a contribution proposal, created by the proposer
# (Bob) in his own process, as interfacer-client's proposeContribution.
defp propose!(c, process_id) do
	ctx = Factory.ctx(c.bob)
	%{
		cite: Intent.Domain.create!(ctx, %{action_id: "cite", input_of_id: process_id,
			provider_id: c.bob.id, resource_inventoried_as_id: c.fork, resource_quantity: qty(c)}),
		accept: Intent.Domain.create!(ctx, %{action_id: "accept", input_of_id: process_id,
			receiver_id: c.alice.id, resource_inventoried_as_id: c.origin, resource_quantity: qty(c)}),
		modify: Intent.Domain.create!(ctx, %{action_id: "modify", output_of_id: process_id,
			receiver_id: c.alice.id, resource_inventoried_as_id: c.origin, resource_quantity: qty(c)}),
	}
end

# The same three intents on a legacy process, inserted raw (no control
# rows anywhere), as they exist in a pre-upgrade database.
defp propose_raw!(c, process_id) do
	ins = fn attrs ->
		Repo.insert!(struct(Intent, Map.merge(%{
			resource_quantity_has_unit_id: c.unit.id,
			resource_quantity_has_numerical_value: Decimal.new(1),
		}, attrs)))
	end
	%{
		cite: ins.(%{action_id: "cite", input_of_id: process_id, provider_id: c.bob.id,
			resource_inventoried_as_id: c.fork}),
		accept: ins.(%{action_id: "accept", input_of_id: process_id, receiver_id: c.alice.id,
			resource_inventoried_as_id: c.origin}),
		modify: ins.(%{action_id: "modify", output_of_id: process_id, receiver_id: c.alice.id,
			resource_inventoried_as_id: c.origin}),
	}
end

# The owner's events of interfacer-gui's ACCEPT_PROPOSAL, attached to
# the proposer's `process_id`.
defp accept!(c, signer, process_id) do
	ctx = Factory.ctx(signer)
	base = %{resource_quantity: qty(c), has_point_in_time: Factory.now()}
	with {:ok, cite} <- EconomicEvent.Domain.create(ctx, Map.merge(base, %{action_id: "cite",
				input_of_id: process_id, provider_id: c.bob.id, receiver_id: c.alice.id,
				resource_inventoried_as_id: c.fork})),
			{:ok, accept} <- EconomicEvent.Domain.create(ctx, Map.merge(base, %{action_id: "accept",
				input_of_id: process_id, provider_id: c.alice.id, receiver_id: c.alice.id,
				resource_inventoried_as_id: c.origin})),
			{:ok, modify} <- EconomicEvent.Domain.create(ctx, Map.merge(base, %{action_id: "modify",
				output_of_id: process_id, provider_id: c.alice.id, receiver_id: c.alice.id,
				resource_inventoried_as_id: c.origin})) do
		{:ok, %{cite: cite, accept: accept, modify: modify}}
	end
end

defp satisfy!(signer, intents, events) do
	for k <- [:cite, :accept, :modify] do
		assert {:ok, %Satisfaction{}} = Satisfaction.Domain.create(Factory.ctx(signer),
			%{satisfies_id: intents[k].id, satisfied_by_event_id: events[k].id})
	end
end

test "the owner attaches cite/accept/modify to the proposer's process holding intents naming her", c do
	process = Factory.insert_process!(c.bob)
	intents = propose!(c, process.id)

	assert {:ok, events} = accept!(c, c.alice, process.id)
	assert events.cite.input_of_id == process.id
	assert events.modify.output_of_id == process.id
	satisfy!(c.alice, intents, events)
end

test "once the inviting intents are finished, the owner is denied", c do
	process = Factory.insert_process!(c.bob)
	intents = propose!(c, process.id)
	for k <- [:accept, :modify],
		do: assert {:ok, _} = Intent.Domain.update(Factory.ctx(c.alice), intents[k].id, %{finished: true})

	assert {:error, :forbidden} = accept!(c, c.alice, process.id)
end

test "an org admin is invited when the intent names the organization", c do
	org = Factory.insert!(:organization)
	Factory.insert_admin!(c.carol, org)
	process = Factory.insert_process!(c.bob)
	Intent.Domain.create!(Factory.ctx(c.bob), %{action_id: "work", input_of_id: process.id,
		provider_id: org.id})

	work = fn signer -> EconomicEvent.Domain.create(Factory.ctx(signer), %{action_id: "work",
		input_of_id: process.id, provider_id: org.id, receiver_id: org.id,
		resource_conforms_to_id: c.spec.id, effort_quantity: qty(c), has_point_in_time: Factory.now()})
	end
	assert {:ok, %EconomicEvent{}} = work.(c.carol)
	assert {:error, :forbidden} = work.(c.alice)
end

test "Carol, named by no intent of the process, is denied", c do
	process = Factory.insert_process!(c.bob)
	propose!(c, process.id)

	assert {:error, :forbidden} = EconomicEvent.Domain.create(Factory.ctx(c.carol), %{
		action_id: "work", input_of_id: process.id, provider_id: c.carol.id, receiver_id: c.carol.id,
		resource_conforms_to_id: c.spec.id, effort_quantity: qty(c), has_point_in_time: Factory.now()})
end

test "intent creation is not widened: the invited owner cannot add an intent to the process", c do
	process = Factory.insert_process!(c.bob)
	propose!(c, process.id)

	assert {:error, :forbidden} = Intent.Domain.create(Factory.ctx(c.alice), %{
		action_id: "work", input_of_id: process.id, provider_id: c.alice.id})
end

describe "legacy contribution proposals (no control rows)" do
	test "the owner can accept: events attach via the invitation, satisfactions pass", c do
		process = Factory.insert!(:process)
		intents = propose_raw!(c, process.id)

		assert {:ok, events} = accept!(c, c.alice, process.id)
		satisfy!(c.alice, intents, events)
	end

	test "the owner can reject: all three intents finish", c do
		process = Factory.insert!(:process)
		intents = propose_raw!(c, process.id)
		proposal = Repo.insert!(%Zenflows.VF.Proposal{name: Factory.str("legacy")})
		for {_, i} <- intents,
			do: Repo.insert!(%Zenflows.VF.ProposedIntent{published_in_id: proposal.id, publishes_id: i.id, reciprocal: false})

		for k <- [:cite, :accept, :modify] do
			assert {:ok, %Intent{finished: true}} =
				Intent.Domain.update(Factory.ctx(c.alice), intents[k].id, %{finished: true})
		end
	end

	test "without unfinished intents naming her, the owner cannot attach", c do
		process = Factory.insert!(:process)
		intents = propose_raw!(c, process.id)
		Repo.update_all(from(i in Intent, where: i.id in ^[intents.accept.id, intents.modify.id]),
			set: [finished: true])

		assert {:error, :forbidden} = accept!(c, c.alice, process.id)
	end
end
end
