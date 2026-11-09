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

defmodule ZenflowsTest.Authz.ProposedIntents do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.{Intent, ProposedIntent}

setup do
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person)}
end

# Minimal valid Intent params: `action_id` plus exactly one of
# `provider_id`/`receiver_id` (the changeset requires exactly one).
defp iparams(overrides), do: Map.merge(%{action_id: Factory.build(:action_id)}, overrides)

test "Bob links his own intent to his own proposal: ok", c do
	proposal = Factory.insert_proposal!(c.bob)
	{:ok, int} = Intent.Domain.create(Factory.ctx(c.bob), iparams(%{provider_id: c.bob.id}))
	assert {:ok, %ProposedIntent{}} =
		ProposedIntent.Domain.create(Factory.ctx(c.bob),
			%{published_in_id: proposal.id, publishes_id: int.id})
end

test "Bob links his intent to Alice's proposal: forbidden", c do
	proposal = Factory.insert_proposal!(c.alice)
	{:ok, int} = Intent.Domain.create(Factory.ctx(c.bob), iparams(%{provider_id: c.bob.id}))
	assert {:error, :forbidden} =
		ProposedIntent.Domain.create(Factory.ctx(c.bob),
			%{published_in_id: proposal.id, publishes_id: int.id})
end

test "Bob links Alice's intent (Bob is not a party nor a controller) to Bob's proposal: forbidden", c do
	proposal = Factory.insert_proposal!(c.bob)
	{:ok, int} = Intent.Domain.create(Factory.ctx(c.alice), iparams(%{provider_id: c.alice.id}))
	assert {:error, :forbidden} =
		ProposedIntent.Domain.create(Factory.ctx(c.bob),
			%{published_in_id: proposal.id, publishes_id: int.id})
end

test "an intent naming Bob as provider but controlled by Alice: ok for Bob on his proposal", c do
	proc = Factory.insert_process!(c.alice)
	{:ok, int} = Intent.Domain.create(Factory.ctx(c.alice),
		iparams(%{input_of_id: proc.id, provider_id: c.bob.id}))
	proposal = Factory.insert_proposal!(c.bob)
	assert {:ok, %ProposedIntent{}} =
		ProposedIntent.Domain.create(Factory.ctx(c.bob),
			%{published_in_id: proposal.id, publishes_id: int.id})
end

test "only the proposal controller deletes the link", c do
	proposal = Factory.insert_proposal!(c.bob)
	{:ok, int} = Intent.Domain.create(Factory.ctx(c.bob), iparams(%{provider_id: c.bob.id}))
	{:ok, pi} = ProposedIntent.Domain.create(Factory.ctx(c.bob),
		%{published_in_id: proposal.id, publishes_id: int.id})

	assert {:error, :forbidden} = ProposedIntent.Domain.delete(Factory.ctx(c.alice), pi.id)
	assert {:ok, %ProposedIntent{}} = ProposedIntent.Domain.delete(Factory.ctx(c.bob), pi.id)
end
end
