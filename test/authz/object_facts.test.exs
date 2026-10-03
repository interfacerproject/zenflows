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

defmodule ZenflowsTest.Authz.ObjectFacts do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.Authz.{Facts, ObjectControl}
alias Zenflows.VF.{EconomicEvent, Intent, Process, ProposedIntent, Satisfaction}

describe "for_object/4" do
	setup do
		%{alice: Factory.insert!(:person), proc: Factory.insert!(:process)}
	end

	test "process without a control row: target loaded, no control, empty admin_of", c do
		f = Facts.for_object(Repo, Factory.ctx(c.alice), "process", c.proc.id)
		assert %Facts{target: %Process{id: id}, control: nil} = f
		assert id == c.proc.id
		assert f.admin_of == MapSet.new()
	end

	test "process with a control row: target and control loaded, admin_of has the controlling org for an admin", c do
		org = Factory.insert!(:organization)
		Factory.insert_admin!(c.alice, org)
		%{target_type: "process", target_id: c.proc.id, controller_id: org.id, source: :creation}
		|> ObjectControl.changeset()
		|> Repo.insert!()

		f = Facts.for_object(Repo, Factory.ctx(c.alice), "process", c.proc.id)
		assert %Facts{target: %Process{id: pid}, control: %ObjectControl{controller_id: cid}} = f
		assert pid == c.proc.id
		assert cid == org.id
		assert MapSet.member?(f.admin_of, org.id)
	end
end

describe "for_intent_create/3" do
	test "process_controls keyed by the process id" do
		alice = Factory.insert!(:person)
		bob = Factory.insert!(:person)
		proc = Factory.insert!(:process)
		%{target_type: "process", target_id: proc.id, controller_id: bob.id, source: :creation}
		|> ObjectControl.changeset()
		|> Repo.insert!()

		f = Facts.for_intent_create(Repo, Factory.ctx(alice), %{input_of_id: proc.id})
		proc_id = proc.id
		assert %{^proc_id => %ObjectControl{controller_id: cid}} = f.process_controls
		assert cid == bob.id
	end
end

describe "for_intent_update/4" do
	test "sibling_parties contains the receiver of a sibling intent published in the same proposal" do
		alice = Factory.insert!(:person)
		bob = Factory.insert!(:person)
		proposal = Factory.insert!(:proposal)
		target = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: bob.id}) |> Repo.insert!()
		sibling = Intent.changeset(%{action_id: Factory.build(:action_id), receiver_id: alice.id}) |> Repo.insert!()
		ProposedIntent.Domain.create!(%{publishes_id: target.id, published_in_id: proposal.id})
		ProposedIntent.Domain.create!(%{publishes_id: sibling.id, published_in_id: proposal.id})

		f = Facts.for_intent_update(Repo, Factory.ctx(bob), target.id, %{})
		assert %Facts{target: %Intent{id: tid}} = f
		assert tid == target.id
		assert MapSet.member?(f.sibling_parties, alice.id)
	end

	test "finished_only is true only for exactly %{finished: true} besides :id" do
		bob = Factory.insert!(:person)
		target = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: bob.id}) |> Repo.insert!()

		assert %Facts{finished_only: true} =
			Facts.for_intent_update(Repo, Factory.ctx(bob), target.id, %{id: target.id, finished: true})
		assert %Facts{finished_only: false} =
			Facts.for_intent_update(Repo, Factory.ctx(bob), target.id, %{id: target.id, finished: true, note: "n"})
		assert %Facts{finished_only: false} =
			Facts.for_intent_update(Repo, Factory.ctx(bob), target.id, %{id: target.id, finished: false})
	end

	test "finished_only is true for an equivalent string-keyed params map" do
		bob = Factory.insert!(:person)
		target = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: bob.id}) |> Repo.insert!()

		assert %Facts{finished_only: true} =
			Facts.for_intent_update(Repo, Factory.ctx(bob), target.id, %{"id" => target.id, "finished" => true})
	end

	test "params changing input_of_id load new_target and that process's control into process_controls" do
		alice = Factory.insert!(:person)
		bob = Factory.insert!(:person)
		proc = Factory.insert!(:process)
		%{target_type: "process", target_id: proc.id, controller_id: bob.id, source: :creation}
		|> ObjectControl.changeset()
		|> Repo.insert!()
		target = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()

		f = Facts.for_intent_update(Repo, Factory.ctx(alice), target.id, %{input_of_id: proc.id})
		assert %Facts{new_target: %{input_of_id: input_of_id, provider_id: provider_id}} = f
		assert input_of_id == proc.id
		assert provider_id == alice.id
		proc_id = proc.id
		assert %{^proc_id => %ObjectControl{controller_id: cid}} = f.process_controls
		assert cid == bob.id
	end

	test "params without any structural key leave new_target nil" do
		alice = Factory.insert!(:person)
		target = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()

		assert %Facts{new_target: nil} =
			Facts.for_intent_update(Repo, Factory.ctx(alice), target.id, %{note: "n"})
	end

	test "a structural field present at its current value is not a change: new_target stays nil" do
		alice = Factory.insert!(:person)
		proc = Factory.insert!(:process)
		target = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id,
			input_of_id: proc.id}) |> Repo.insert!()

		# No control row for `proc` at all: if this were (wrongly) treated
		# as a change, the create-style check downstream would need a
		# control alice doesn't have.
		assert %Facts{new_target: nil, process_controls: controls} =
			Facts.for_intent_update(Repo, Factory.ctx(alice), target.id, %{input_of_id: proc.id, note: "n"})
		assert controls == %{}
	end

	test "a string-keyed structural param still fills new_target" do
		alice = Factory.insert!(:person)
		bob = Factory.insert!(:person)

		target = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()

		f = Facts.for_intent_update(Repo, Factory.ctx(alice), target.id, %{"receiver_id" => bob.id})
		assert %Facts{new_target: %{receiver_id: receiver_id, provider_id: provider_id}} = f
		assert receiver_id == bob.id
		assert provider_id == alice.id
	end

	test "detaching from a process loads that OLD process's control too, alongside the new (empty) state" do
		alice = Factory.insert!(:person)
		bob = Factory.insert!(:person)
		proc = Factory.insert!(:process)
		%{target_type: "process", target_id: proc.id, controller_id: bob.id, source: :creation}
		|> ObjectControl.changeset()
		|> Repo.insert!()
		target = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id,
			input_of_id: proc.id}) |> Repo.insert!()

		f = Facts.for_intent_update(Repo, Factory.ctx(alice), target.id, %{input_of_id: nil})
		assert %Facts{new_target: %{input_of_id: nil}} = f
		proc_id = proc.id
		assert %{^proc_id => %ObjectControl{controller_id: cid}} = f.process_controls
		assert cid == bob.id
	end
end

describe "for_proposed_intent_create/4" do
	test "loads the proposal's control, the intent, and the intent's control" do
		alice = Factory.insert!(:person)
		bob = Factory.insert!(:person)
		proposal = Factory.insert!(:proposal)
		intent = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: bob.id}) |> Repo.insert!()
		%{target_type: "proposal", target_id: proposal.id, controller_id: alice.id, source: :creation}
		|> ObjectControl.changeset() |> Repo.insert!()
		%{target_type: "intent", target_id: intent.id, controller_id: bob.id, source: :creation}
		|> ObjectControl.changeset() |> Repo.insert!()

		f = Facts.for_proposed_intent_create(Repo, Factory.ctx(alice), proposal.id, intent.id)
		assert %Facts{control: %ObjectControl{controller_id: cid1, target_type: "proposal"},
			intent: %Intent{id: iid},
			intent_control: %ObjectControl{controller_id: cid2, target_type: "intent"}} = f
		assert cid1 == alice.id
		assert cid2 == bob.id
		assert iid == intent.id
	end
end

describe "for_proposed_intent/3" do
	test "loads the proposed intent and its proposal's control" do
		alice = Factory.insert!(:person)
		proposal = Factory.insert!(:proposal)
		intent = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()
		pi = ProposedIntent.Domain.create!(%{publishes_id: intent.id, published_in_id: proposal.id})
		%{target_type: "proposal", target_id: proposal.id, controller_id: alice.id, source: :creation}
		|> ObjectControl.changeset() |> Repo.insert!()

		f = Facts.for_proposed_intent(Repo, Factory.ctx(alice), pi.id)
		assert %Facts{target: %ProposedIntent{id: pid}, control: %ObjectControl{controller_id: cid}} = f
		assert pid == pi.id
		assert cid == alice.id
	end

	test "no proposed intent: target and control are both nil" do
		alice = Factory.insert!(:person)
		assert %Facts{target: nil, control: nil} = Facts.for_proposed_intent(Repo, Factory.ctx(alice), Factory.id())
	end
end

describe "for_satisfaction_create/3" do
	test "loads event and intent" do
		alice = Factory.insert!(:person)
		event_id = Factory.insert_economic_event!().id
		intent = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()

		f = Facts.for_satisfaction_create(Repo, Factory.ctx(alice),
			%{satisfied_by_event_id: event_id, satisfies_id: intent.id})
		assert %Facts{event: %EconomicEvent{id: eid}, intent: %Intent{id: iid}} = f
		assert eid == event_id
		assert iid == intent.id
	end

	test "event is nil when only satisfied_by_commitment_id is given" do
		alice = Factory.insert!(:person)
		commitment_id = Factory.insert!(:commitment).id
		intent = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()

		f = Facts.for_satisfaction_create(Repo, Factory.ctx(alice),
			%{satisfied_by_commitment_id: commitment_id, satisfies_id: intent.id})
		assert %Facts{event: nil, intent: %Intent{id: iid}} = f
		assert iid == intent.id
	end
end

describe "for_satisfaction/4" do
	test "loads the current event and intent; new_event/new_intent are nil without params" do
		alice = Factory.insert!(:person)
		event_id = Factory.insert_economic_event!().id
		intent = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()
		satisfaction = Satisfaction.changeset(%{satisfied_by_event_id: event_id, satisfies_id: intent.id})
			|> Repo.insert!()

		f = Facts.for_satisfaction(Repo, Factory.ctx(alice), satisfaction.id)
		assert %Facts{event: %EconomicEvent{id: eid}, intent: %Intent{id: iid}, new_event: nil, new_intent: nil} = f
		assert eid == event_id
		assert iid == intent.id
	end

	test "satisfied_by_event_id in params loads new_event" do
		alice = Factory.insert!(:person)
		event_id = Factory.insert_economic_event!().id
		new_event_id = Factory.insert_economic_event!().id
		intent = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()
		satisfaction = Satisfaction.changeset(%{satisfied_by_event_id: event_id, satisfies_id: intent.id})
			|> Repo.insert!()

		f = Facts.for_satisfaction(Repo, Factory.ctx(alice), satisfaction.id,
			%{satisfied_by_event_id: new_event_id})
		assert %Facts{new_event: %EconomicEvent{id: new_eid}, new_intent: nil, repoint?: true} = f
		assert new_eid == new_event_id
	end

	test "re-pointing to a bare commitment marks repoint? and loads a nil new_event" do
		alice = Factory.insert!(:person)
		event_id = Factory.insert_economic_event!().id
		commitment_id = Factory.insert!(:commitment).id
		intent = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()
		satisfaction = Satisfaction.changeset(%{satisfied_by_event_id: event_id, satisfies_id: intent.id})
			|> Repo.insert!()

		f = Facts.for_satisfaction(Repo, Factory.ctx(alice), satisfaction.id,
			%{satisfied_by_event_id: nil, satisfied_by_commitment_id: commitment_id})
		assert %Facts{repoint?: true, new_event: nil} = f
	end

	test "params that don't touch either satisfied-by field are not a re-point" do
		alice = Factory.insert!(:person)
		event_id = Factory.insert_economic_event!().id
		intent = Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: alice.id}) |> Repo.insert!()
		satisfaction = Satisfaction.changeset(%{satisfied_by_event_id: event_id, satisfies_id: intent.id})
			|> Repo.insert!()

		f = Facts.for_satisfaction(Repo, Factory.ctx(alice), satisfaction.id, %{note: "n"})
		assert %Facts{repoint?: false, new_event: nil} = f
	end
end
end
