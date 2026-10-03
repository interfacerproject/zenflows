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
alias Zenflows.VF.{EconomicEvent, Intent, Process, ProposedIntent}

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
end
