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

defmodule ZenflowsTest.Authz.Intents do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.Authz.ObjectControl
alias Zenflows.VF.{Intent, Intent.Domain, ProposedIntent}

setup do
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person)}
end

# Minimal valid Intent params: `action_id` plus exactly one of
# `provider_id`/`receiver_id` (the changeset requires exactly one).
defp iparams(overrides), do: Map.merge(%{action_id: Factory.build(:action_id)}, overrides)

test "creating an intent inputOf one's own process, naming only the receiver: ok, controls it", c do
	proc = Factory.insert_process!(c.bob)
	params = iparams(%{input_of_id: proc.id, receiver_id: c.alice.id})
	assert {:ok, %Intent{} = int} = Domain.create(Factory.ctx(c.bob), params)
	assert {:ok, %ObjectControl{controller_id: cid}} = ObjectControl.Domain.one("intent", int.id)
	assert cid == c.bob.id
end

test "creating an intent inputOf someone else's process: forbidden even when named receiver", c do
	proc = Factory.insert_process!(c.alice)
	params = iparams(%{input_of_id: proc.id, receiver_id: c.alice.id})
	assert {:error, :forbidden} = Domain.create(Factory.ctx(c.bob), params)
end

test "process-less intent: naming only the other party is forbidden, naming oneself is ok", c do
	assert {:error, :forbidden} = Domain.create(Factory.ctx(c.bob), iparams(%{receiver_id: c.alice.id}))
	assert {:ok, %Intent{}} = Domain.create(Factory.ctx(c.bob), iparams(%{provider_id: c.bob.id}))
end

test "a named receiver may update finished on the controller's intent", c do
	proc = Factory.insert_process!(c.bob)
	{:ok, int} = Domain.create(Factory.ctx(c.bob), iparams(%{input_of_id: proc.id, receiver_id: c.alice.id}))
	assert {:ok, %Intent{finished: true}} = Domain.update(Factory.ctx(c.alice), int.id, %{finished: true})
end

describe "contribution shape (proposal publishing a cite and an accept intent)" do
	setup c do
		proposal = Factory.insert_proposal!(c.bob)
		{:ok, cite} = Domain.create(Factory.ctx(c.bob), iparams(%{provider_id: c.bob.id}))
		{:ok, accept} = Domain.create(Factory.ctx(c.alice), iparams(%{receiver_id: c.alice.id}))
		Repo.insert!(ProposedIntent.changeset(%{published_in_id: proposal.id, publishes_id: cite.id}))
		Repo.insert!(ProposedIntent.changeset(%{published_in_id: proposal.id, publishes_id: accept.id}))
		%{cite: cite, accept: accept}
	end

	test "the sibling's named party may finish the cite intent with only :finished", c do
		assert {:ok, %Intent{finished: true}} = Domain.update(Factory.ctx(c.alice), c.cite.id, %{finished: true})
	end

	test "the same update with an extra field is forbidden (not finished_only anymore)", c do
		assert {:error, :forbidden} =
			Domain.update(Factory.ctx(c.alice), c.cite.id, %{finished: true, note: "x"})
	end

	test "a party on neither intent is forbidden", c do
		carol = Factory.insert!(:person)
		assert {:error, :forbidden} = Domain.update(Factory.ctx(carol), c.cite.id, %{finished: true})
	end
end

test "only the controller deletes, and deleting removes the control row", c do
	{:ok, int} = Domain.create(Factory.ctx(c.bob), iparams(%{provider_id: c.bob.id}))
	assert {:error, :forbidden} = Domain.delete(Factory.ctx(c.alice), int.id)
	assert {:ok, %Intent{}} = Domain.delete(Factory.ctx(c.bob), int.id)
	assert {:error, "not found"} = ObjectControl.Domain.one("intent", int.id)
end

test "legacy intent (no control row): its provider may update it, but nobody may delete it", c do
	legacy =
		Intent.changeset(%{action_id: Factory.build(:action_id), provider_id: c.alice.id})
		|> Repo.insert!()

	assert {:ok, %Intent{finished: true}} = Domain.update(Factory.ctx(c.alice), legacy.id, %{finished: true})
	assert {:error, :forbidden} = Domain.delete(Factory.ctx(c.alice), legacy.id)
	assert {:error, :forbidden} = Domain.delete(Factory.ctx(c.bob), legacy.id)
end
end
