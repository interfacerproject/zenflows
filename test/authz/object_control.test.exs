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

defmodule ZenflowsTest.Authz.ObjectControl do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Multi
alias Zenflows.Authz.{ExecutionContext, ObjectControl, PermissionLog}

defp admin_ctx(),
	do: ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})

setup do
	%{alice: Factory.insert!(:person), proc: Factory.insert!(:process)}
end

test "multi_on_create records the person as controller and logs it", c do
	{:ok, %{"p.control" => control}} =
		Multi.new()
		|> Multi.put("p", c.proc)
		|> ObjectControl.Domain.multi_on_create(Factory.ctx(c.alice), "process", "p")
		|> Repo.transaction()
	assert %ObjectControl{target_type: "process", source: :creation, controller_id: cid} = control
	assert cid == c.alice.id
	proc_id = c.proc.id
	assert [%PermissionLog{action: "object_control.set", target_type: "process", target_id: ^proc_id}] =
		Repo.all(from l in PermissionLog, where: l.target_id == ^proc_id)
end

test "multi_on_create is a no-op for anonymous and services", c do
	for ctx <- [Factory.ctx(), ExecutionContext.service(:import, nil)] do
		{:ok, _} =
			Multi.new()
			|> Multi.put("p", c.proc)
			|> ObjectControl.Domain.multi_on_create(ctx, "process", "p")
			|> Repo.transaction()
	end
	assert {:error, "not found"} = ObjectControl.Domain.one("process", c.proc.id)
end

test "multi_remove deletes the row and logs; absent row is fine", c do
	{:ok, _} = ObjectControl.Domain.assign(admin_ctx(), "process", c.proc.id, c.alice.id, "ticket")
	{:ok, _} = Multi.new() |> ObjectControl.Domain.multi_remove(Factory.ctx(c.alice), "process", c.proc.id) |> Repo.transaction()
	assert {:error, "not found"} = ObjectControl.Domain.one("process", c.proc.id)
	assert {:ok, _} = Multi.new() |> ObjectControl.Domain.multi_remove(Factory.ctx(c.alice), "process", c.proc.id) |> Repo.transaction()
	proc_id = c.proc.id
	assert ["object_control.remove", "object_control.set"] ==
		Repo.all(from l in PermissionLog, where: l.target_id == ^proc_id, select: l.action) |> Enum.sort()
end

test "assign: admin key only, reason required, replaces and bumps epoch", c do
	bob = Factory.insert!(:person)
	assert {:error, :forbidden} = ObjectControl.Domain.assign(Factory.ctx(c.alice), "process", c.proc.id, c.alice.id, "x")
	assert {:error, "reason is required"} = ObjectControl.Domain.assign(admin_ctx(), "process", c.proc.id, c.alice.id, " ")
	assert {:ok, %ObjectControl{epoch: 0, source: :admin}} =
		ObjectControl.Domain.assign(admin_ctx(), "process", c.proc.id, c.alice.id, "first")
	assert {:ok, %ObjectControl{epoch: 1, controller_id: cid}} =
		ObjectControl.Domain.assign(admin_ctx(), "process", c.proc.id, bob.id, "second")
	assert cid == bob.id
	assert {:error, _} = ObjectControl.Domain.assign(admin_ctx(), "planet", c.proc.id, bob.id, "x")
end
end
