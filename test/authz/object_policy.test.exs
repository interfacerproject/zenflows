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

defmodule ZenflowsTest.Authz.ObjectPolicy do
use ExUnit.Case, async: true

alias Zenflows.Authz.{ExecutionContext, Facts, ObjectControl, Policy}
alias Zenflows.DB.ID
alias Zenflows.VF.{EconomicEvent, Intent, Person, ProposedIntent, Satisfaction}

@strict [enforce: true, allow_unchecked: false]

setup do
	a = ID.gen(); b = ID.gen(); org = ID.gen(); p1 = ID.gen(); p2 = ID.gen()
	%{a: a, b: b, org: org, p1: p1, p2: p2,
		as_a: ExecutionContext.from_resolution(%{context: %{req_user: %Person{id: a}}}),
		as_b: ExecutionContext.from_resolution(%{context: %{req_user: %Person{id: b}}})}
end

defp ctl(id, type \\ "process"), do: %ObjectControl{target_type: type, target_id: ID.gen(), controller_id: id}
defp auth(ctx, action, f), do: Policy.authorize(ctx, action, f, @strict)

test "create of process/proposal: any person", c do
	for a <- ~w[process.create proposal.create], do: assert :ok = auth(c.as_b, a, %Facts{})
end

test "update/delete of process/proposal/intent: controller or admin of controlling org", c do
	for {a, type} <- [{"process.update", "process"}, {"process.delete", "process"},
			{"proposal.update", "proposal"}, {"proposal.delete", "proposal"},
			{"intent.delete", "intent"}] do
		assert :ok = auth(c.as_a, a, %Facts{control: ctl(c.a, type)})
		assert {:error, :forbidden} = auth(c.as_b, a, %Facts{control: ctl(c.a, type)})
		assert :ok = auth(c.as_b, a, %Facts{control: ctl(c.org, type), admin_of: MapSet.new([c.org])})
		assert {:error, :forbidden} = auth(c.as_a, a, %Facts{control: nil})
	end
end

test "a control of the wrong target type does not authorize: process control vs. intent.delete", c do
	assert {:error, :forbidden} = auth(c.as_a, "intent.delete", %Facts{control: ctl(c.a, "process")})
end

describe "intent.create" do
	test "without process: signer must act for provider or receiver", c do
		assert :ok = auth(c.as_a, "intent.create", %Facts{target: %{provider_id: c.a}})
		assert :ok = auth(c.as_a, "intent.create", %Facts{target: %{receiver_id: c.a}})
		assert {:error, :forbidden} = auth(c.as_b, "intent.create", %Facts{target: %{receiver_id: c.a}})
	end

	test "with process: signer must control it, and may then name only the other side", c do
		f = %Facts{target: %{input_of_id: c.p1, receiver_id: c.a}, process_controls: %{c.p1 => ctl(c.b)}}
		assert :ok = auth(c.as_b, "intent.create", f)
		assert {:error, :forbidden} = auth(c.as_a, "intent.create", f)
		assert {:error, :forbidden} =
			auth(c.as_b, "intent.create", %{f | process_controls: %{}})
	end

	test "with both processes: both must be controlled", c do
		f = %Facts{target: %{input_of_id: c.p1, output_of_id: c.p2, provider_id: c.b},
			process_controls: %{c.p1 => ctl(c.b), c.p2 => ctl(c.a)}}
		assert {:error, :forbidden} = auth(c.as_b, "intent.create", f)
	end
end

describe "intent.update" do
	test "controller, named party, or finished-only via same proposal", c do
		int = %Intent{provider_id: c.a, receiver_id: nil}
		assert :ok = auth(c.as_a, "intent.update", %Facts{target: int})
		assert :ok = auth(c.as_b, "intent.update", %Facts{target: int, control: ctl(c.b, "intent")})
		assert {:error, :forbidden} = auth(c.as_b, "intent.update", %Facts{target: int})
		sib = %Facts{target: int, sibling_parties: MapSet.new([c.b]), finished_only: true}
		assert :ok = auth(c.as_b, "intent.update", sib)
		assert {:error, :forbidden} = auth(c.as_b, "intent.update", %{sib | finished_only: false})
	end

	test "unchanged structure (no new_target): existing rule alone decides", c do
		int = %Intent{provider_id: c.a, receiver_id: nil}
		assert :ok = auth(c.as_a, "intent.update", %Facts{target: int, new_target: nil})
	end

	test "re-pointing input_of to a process the signer doesn't control: forbidden", c do
		int = %Intent{provider_id: c.a, receiver_id: nil}
		f = %Facts{target: int,
			new_target: %{provider_id: c.a, receiver_id: nil, input_of_id: c.p1, output_of_id: nil},
			process_controls: %{c.p1 => ctl(c.b)}}
		assert {:error, :forbidden} = auth(c.as_a, "intent.update", f)
	end

	test "controller changing the receiver to someone they don't act for: forbidden", c do
		int = %Intent{provider_id: c.org, receiver_id: nil}
		f = %Facts{target: int, control: ctl(c.a, "intent"),
			new_target: %{provider_id: c.org, receiver_id: c.b, input_of_id: nil, output_of_id: nil}}
		assert {:error, :forbidden} = auth(c.as_a, "intent.update", f)
	end

	test "a named party detaching from a process they don't control: forbidden", c do
		int = %Intent{provider_id: nil, receiver_id: c.a, input_of_id: c.p1}
		f = %Facts{target: int,
			new_target: %{provider_id: nil, receiver_id: c.a, input_of_id: nil, output_of_id: nil},
			process_controls: %{c.p1 => ctl(c.b)}}
		assert {:error, :forbidden} = auth(c.as_a, "intent.update", f)
	end

	test "detaching from a process the signer controls (the process controller): ok", c do
		int = %Intent{provider_id: nil, receiver_id: c.a, input_of_id: c.p1}
		f = %Facts{target: int,
			new_target: %{provider_id: nil, receiver_id: c.a, input_of_id: nil, output_of_id: nil},
			process_controls: %{c.p1 => ctl(c.a)}}
		assert :ok = auth(c.as_a, "intent.update", f)
	end

	test "swapping to a different process the signer doesn't control the old one of: forbidden", c do
		int = %Intent{provider_id: nil, receiver_id: c.a, input_of_id: c.p1}
		f = %Facts{target: int,
			new_target: %{provider_id: nil, receiver_id: c.a, input_of_id: c.p2, output_of_id: nil},
			process_controls: %{c.p1 => ctl(c.b), c.p2 => ctl(c.a)}}
		assert {:error, :forbidden} = auth(c.as_a, "intent.update", f)
	end
end

describe "proposed_intent" do
	test "create: control proposal and (control intent or party)", c do
		int = %Intent{provider_id: c.a}
		f = %Facts{control: ctl(c.a, "proposal"), intent: int}
		assert :ok = auth(c.as_a, "proposed_intent.create", f)
		assert {:error, :forbidden} = auth(c.as_b, "proposed_intent.create", f)
		assert {:error, :forbidden} =
			auth(c.as_b, "proposed_intent.create", %{f | control: ctl(c.b, "proposal")})
		assert :ok = auth(c.as_b, "proposed_intent.create",
			%{f | control: ctl(c.b, "proposal"), intent_control: ctl(c.b, "intent")})
	end

	test "delete: control the proposal", c do
		f = %Facts{target: %ProposedIntent{}, control: ctl(c.a, "proposal")}
		assert :ok = auth(c.as_a, "proposed_intent.delete", f)
		assert {:error, :forbidden} = auth(c.as_b, "proposed_intent.delete", f)
	end
end

describe "satisfaction" do
	test "create: party of the event, and event shares an agent with the intent", c do
		evt = %EconomicEvent{provider_id: c.b, receiver_id: c.a}
		assert :ok = auth(c.as_a, "satisfaction.create",
			%Facts{event: evt, intent: %Intent{provider_id: c.b}})
		assert {:error, :forbidden} = auth(c.as_a, "satisfaction.create",
			%Facts{event: evt, intent: %Intent{provider_id: c.org}})
		assert {:error, :forbidden} = auth(c.as_b, "satisfaction.create",
			%Facts{event: %EconomicEvent{provider_id: c.a, receiver_id: c.a}, intent: %Intent{provider_id: c.a}})
		assert {:error, :forbidden} = auth(c.as_a, "satisfaction.create",
			%Facts{event: nil, intent: %Intent{provider_id: c.a}})
	end

	test "update/delete: party of the satisfying event", c do
		for a <- ~w[satisfaction.update satisfaction.delete] do
			f = %Facts{target: %Satisfaction{}, event: %EconomicEvent{provider_id: c.a, receiver_id: c.a}}
			assert :ok = auth(c.as_a, a, f)
			assert {:error, :forbidden} = auth(c.as_b, a, f)
		end
	end

	test "update: unchanged target (no new_event/new_intent): existing rule alone decides", c do
		f = %Facts{target: %Satisfaction{}, event: %EconomicEvent{provider_id: c.a, receiver_id: c.a}}
		assert :ok = auth(c.as_a, "satisfaction.update", f)
	end

	test "update: re-pointing to an event the signer isn't a party to: forbidden", c do
		f = %Facts{target: %Satisfaction{},
			event: %EconomicEvent{provider_id: c.a, receiver_id: c.a},
			intent: %Intent{provider_id: c.a},
			repoint?: true,
			new_event: %EconomicEvent{provider_id: c.org, receiver_id: c.b}}
		assert {:error, :forbidden} = auth(c.as_a, "satisfaction.update", f)
	end

	test "update: re-pointing to a bare commitment (no event): forbidden", c do
		f = %Facts{target: %Satisfaction{},
			event: %EconomicEvent{provider_id: c.a, receiver_id: c.a},
			intent: %Intent{provider_id: c.a},
			repoint?: true,
			new_event: nil}
		assert {:error, :forbidden} = auth(c.as_a, "satisfaction.update", f)
	end

	test "update: re-pointing satisfies_id to an intent sharing no agent with the event: forbidden", c do
		f = %Facts{target: %Satisfaction{},
			event: %EconomicEvent{provider_id: c.a, receiver_id: c.a},
			intent: %Intent{provider_id: c.a},
			new_intent: %Intent{provider_id: c.org}}
		assert {:error, :forbidden} = auth(c.as_a, "satisfaction.update", f)
	end
end

test "object_control.assign is admin-key only", c do
	assert {:error, :forbidden} = auth(c.as_a, "object_control.assign", %Facts{})
	admin = ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})
	assert :ok = auth(admin, "object_control.assign", %Facts{})
end

test "services may create processes, proposals and intents" do
	for name <- [:import, :migration], a <- ~w[process.create proposal.create intent.create] do
		assert :ok = Policy.authorize(ExecutionContext.service(name, nil), a, %Facts{}, @strict)
	end
end
end
