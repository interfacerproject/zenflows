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

defmodule ZenflowsTest.Authz.Processes do
use ZenflowsTest.Help.EctoCase, async: true

import ZenflowsTest.Help.AbsinCase, only: [run!: 2]

alias Zenflows.Authz.{ExecutionContext, ObjectControl}
alias Zenflows.VF.{Process, Proposal}

setup do
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person)}
end

test "creator controls a new process; others cannot update or delete it", c do
	{:ok, proc} = Process.Domain.create(Factory.ctx(c.alice), %{name: "p"})
	assert {:ok, %ObjectControl{controller_id: cid}} = ObjectControl.Domain.one("process", proc.id)
	assert cid == c.alice.id
	assert {:error, :forbidden} = Process.Domain.update(Factory.ctx(c.bob), proc.id, %{name: "x"})
	assert {:error, :forbidden} = Process.Domain.delete(Factory.ctx(c.bob), proc.id)
	assert {:ok, %Process{name: "y"}} = Process.Domain.update(Factory.ctx(c.alice), proc.id, %{name: "y"})
	assert {:ok, _} = Process.Domain.delete(Factory.ctx(c.alice), proc.id)
	assert {:error, "not found"} = ObjectControl.Domain.one("process", proc.id)
end

test "legacy process (no control row) is deny-all until assigned", c do
	proc = Factory.insert!(:process)
	assert {:error, :forbidden} = Process.Domain.update(Factory.ctx(c.alice), proc.id, %{name: "x"})
	admin = ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})
	{:ok, _} = ObjectControl.Domain.assign(admin, "process", proc.id, c.alice.id, "legacy fix")
	assert {:ok, _} = Process.Domain.update(Factory.ctx(c.alice), proc.id, %{name: "x"})
end

test "proposals follow the same rules", c do
	{:ok, prop} = Proposal.Domain.create(Factory.ctx(c.alice), %{name: "sale"})
	assert {:error, :forbidden} = Proposal.Domain.update(Factory.ctx(c.bob), prop.id, %{note: "x"})
	assert {:ok, _} = Proposal.Domain.update(Factory.ctx(c.alice), prop.id, %{note: "y"})
	assert {:error, :forbidden} = Proposal.Domain.delete(Factory.ctx(c.bob), prop.id)
end

test "the ProcessGroup grouping check still applies", c do
	parent = Factory.insert!(:process_group)
	child = Factory.insert!(:process_group)
	Repo.update_all(from(g in Zenflows.VF.ProcessGroup, where: g.id == ^child.id), set: [grouped_in_id: parent.id])
	assert {:error, %Ecto.Changeset{}} =
		Process.Domain.create(Factory.ctx(c.alice), %{name: "p", grouped_in_id: parent.id})
end

test "objectControl query", c do
	{:ok, proc} = Process.Domain.create(Factory.ctx(c.alice), %{name: "p"})
	assert %{data: %{"objectControl" => %{"controller" => %{"id" => id}, "source" => "creation"}}} =
		run!("""
			query ($id: ID!) { objectControl(targetType: "process", targetId: $id) { controller { id } source epoch } }
		""", vars: %{"id" => proc.id})
	assert id == c.alice.id
end

test "objectControl: unknown targetId is null; a malformed one is an ID argument error, not an exception", c do
	{:ok, proc} = Process.Domain.create(Factory.ctx(c.alice), %{name: "p"})
	for id <- [Factory.id(), proc.id] do
		assert %{data: %{"objectControl" => nil}} =
			run!("""
				query ($id: ID!) { objectControl(targetType: "proposal", targetId: $id) { epoch } }
			""", vars: %{"id" => id})
	end
	# The ID scalar casts ULIDs, so a malformed id never reaches the resolver.
	assert %{errors: [%{message: ~s(Argument "targetId" has invalid value $id.)}]} =
		run!("""
			query ($id: ID!) { objectControl(targetType: "process", targetId: $id) { epoch } }
		""", vars: %{"id" => "not-a-ulid"})
end

test "assignObjectControl with a malformed targetId or personId is an argument error", c do
	for {t, p} <- [{"not-a-ulid", c.alice.id}, {Factory.id(), "not-a-ulid"}] do
		assert %{errors: [%{message: "Argument " <> _}]} =
			run!("""
				mutation ($t: ID!, $p: ID!) {
					assignObjectControl(targetType: "process", targetId: $t, personId: $p, reason: "x") { epoch }
				}
			""", vars: %{"t" => t, "p" => p})
	end
end
end
