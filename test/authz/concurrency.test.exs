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

defmodule ZenflowsTest.Authz.Concurrency do
# Runs outside the SQL sandbox to get real concurrent transactions.
# async: false modules run alone, after all async modules.
use ExUnit.Case, async: false

import Ecto.Query, only: [from: 2]

alias Ecto.Adapters.SQL.Sandbox
alias Zenflows.Authz.{ExecutionContext, Roles}
alias Zenflows.DB.{ID, Repo}
alias Zenflows.VF.{AgentRelationship, Organization, Person}

defp ctx(per), do: ExecutionContext.from_resolution(%{context: %{req_user: per}})

defp person!() do
	s = ID.gen()
	Repo.insert!(Person.changeset(%{name: "p#{s}", user: "u#{s}", email: "#{s}@example.com"}))
end

setup do
	ids = Sandbox.unboxed_run(Repo, fn ->
		alice = person!()
		bob = person!()
		org = Repo.insert!(Organization.changeset(%Organization{}, %{name: "org#{ID.gen()}"}))
		role = Roles.id!(Repo, "org.admin")
		[alice_rel, bob_rel] =
			for per <- [alice, bob] do
				Repo.insert!(%AgentRelationship{subject_id: per.id, object_id: org.id,
					in_scope_of_id: org.id, relationship_id: role})
			end
		%{alice: alice, bob: bob, org: org, alice_rel: alice_rel, bob_rel: bob_rel}
	end)

	on_exit(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			Repo.delete_all(from r in AgentRelationship, where: r.object_id == ^ids.org.id)
			for a <- [ids.alice, ids.bob, ids.org], do: Repo.delete!(a)
			Repo.query!("TRUNCATE zf_permission_log")
		end)
	end)

	ids
end

test "update waiting on a concurrent revoke of the updater is denied", c do
	parent = self()

	revoker = Task.async(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			Repo.transaction(fn ->
				{:ok, _} = AgentRelationship.Domain.delete(ctx(c.bob), c.alice_rel.id)
				send(parent, :revoked_not_committed)
				receive do :commit -> :ok end
			end)
		end)
	end)
	assert_receive :revoked_not_committed, 5_000

	updater = Task.async(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			Organization.Domain.update(ctx(c.alice), c.org.id, %{note: "late"})
		end)
	end)

	# The updater must be blocked on the revoked relationship row.
	assert Task.yield(updater, 300) == nil

	send(revoker.pid, :commit)
	assert {:ok, _} = Task.await(revoker)
	assert {:error, :forbidden} = Task.await(updater)
end
end
