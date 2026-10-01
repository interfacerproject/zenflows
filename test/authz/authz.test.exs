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

defmodule ZenflowsTest.Authz.Authz do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{Facts, Log, PermissionLog}

setup do
	alice = Factory.insert!(:person)
	org = Factory.insert!(:organization)
	%{alice: alice, org: org}
end

test "admin_of: active admin relationships only", %{alice: alice, org: org} do
	rel = Factory.insert_admin!(alice, org)
	other = Factory.insert!(:organization)
	Factory.insert_admin!(alice, other)
	assert Facts.admin_of(Repo, Factory.ctx(alice), [org.id]) == MapSet.new([org.id])
	assert Facts.admin_of(Repo, Factory.ctx(alice), [org.id, other.id, nil]) == MapSet.new([org.id, other.id])
	# only the asked-for organizations, never the actor's others
	assert Facts.admin_of(Repo, Factory.ctx(alice), [other.id]) == MapSet.new([other.id])
	assert Facts.admin_of(Repo, Factory.ctx(alice), [Factory.id(), nil]) == MapSet.new()
	assert Facts.admin_of(Repo, Factory.ctx(alice), []) == MapSet.new()

	rel |> Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update!()
	assert Facts.admin_of(Repo, Factory.ctx(alice), [org.id]) == MapSet.new()
	assert Facts.admin_of(Repo, Factory.ctx(), [org.id]) == MapSet.new()
end

test "multi_authorize aborts the transaction on deny", %{alice: alice, org: org} do
	assert {:error, :authz, :forbidden, _} =
		Multi.new()
		|> Authz.multi_authorize(:authz, Factory.ctx(alice), "organization.update",
			fn repo, _ -> Facts.for_organization(repo, Factory.ctx(alice), org.id) end)
		|> Multi.run(:never, fn _, _ -> flunk("ran after deny") end)
		|> Repo.transaction()
end

test "multi_target: not found when authorized but missing" do
	assert {:error, :one, "not found", _} =
		Multi.new()
		|> Authz.multi_authorize(:authz, Factory.ctx(), "organization.update",
			fn repo, _ -> Facts.for_organization(repo, Factory.ctx(), Factory.id()) end)
		|> Authz.multi_target(:one, :authz)
		|> Repo.transaction()
end

test "deny emits telemetry; enforce: false lets it through", %{alice: alice, org: org} do
	ref = make_ref()
	pid = self()
	:telemetry.attach("authz-test-#{inspect(ref)}", [:zenflows, :authz, :deny],
		fn _, m, meta, _ -> send(pid, {:deny, m, meta}) end, nil)
	on_exit(fn -> :telemetry.detach("authz-test-#{inspect(ref)}") end)

	facts = Facts.for_organization(Repo, Factory.ctx(alice), org.id)
	assert :ok = Authz.authorize(Factory.ctx(alice), "organization.update", facts,
		enforce: false, allow_unchecked: false)
	alice_id = alice.id
	org_id = org.id
	assert_received {:deny, %{count: 1},
		%{actor_id: ^alice_id, action: "organization.update", target_id: ^org_id, enforced: false}}
end

test "Log.multi_insert fills actor, service and request id from ctx", %{alice: alice, org: org} do
	ctx = Factory.ctx(alice)
	{:ok, %{log: log}} =
		Multi.new()
		|> Log.multi_insert(:log, ctx, fn _ ->
			%{action: "test", target_type: "organization", target_id: org.id, actor_id: "forged"}
		end)
		|> Repo.transaction()
	assert %PermissionLog{actor_id: actor, service: :gql, request_id: rid} = log
	assert actor == alice.id
	assert rid == ctx.request_id
end

test "a failing log entry rolls back the change it records" do
	assert {:error, :log, %Ecto.Changeset{}, _} =
		Multi.new()
		|> Multi.insert(:org, Zenflows.VF.Organization.changeset(%{name: "rollback-me"}))
		|> Log.multi_insert(:log, Factory.ctx(), fn _ ->
			%{action: "x", target_type: "organization", target_id: nil}
		end)
		|> Repo.transaction()
	assert Repo.get_by(Zenflows.VF.Organization, name: "rollback-me") == nil
end

test "Log.multi_insert skips nil entries" do
	assert {:ok, %{log: nil}} =
		Multi.new() |> Log.multi_insert(:log, Factory.ctx(), fn _ -> nil end) |> Repo.transaction()
end

test "event decisions go through Authz.authorize with a rule in telemetry", %{alice: alice} do
	ref = make_ref()
	pid = self()
	:telemetry.attach("authz-evt-#{inspect(ref)}", [:zenflows, :authz, :deny],
		fn _, _, meta, _ -> send(pid, {:deny, meta}) end, nil)
	on_exit(fn -> :telemetry.detach("authz-evt-#{inspect(ref)}") end)

	other = Factory.id()
	f = %Zenflows.Authz.EventFacts{action: "work", provider_id: other, receiver_id: other}
	assert {:error, :forbidden} = Authz.authorize(Factory.ctx(alice), "event.create", f)
	assert_received {:deny, %{action: "event.create", rule: :agent, reason: :forbidden}}
	assert :ok = Authz.authorize(Factory.ctx(), "event.create", f)
end

test "MW.Errors maps authz errors to coded GraphQL errors" do
	res = Zenflows.GQL.MW.Errors.call(%Absinthe.Resolution{errors: [:forbidden, :unauthenticated]}, [])
	assert res.errors == [
		%{message: "forbidden", extensions: %{code: "FORBIDDEN"}},
		%{message: "unauthenticated", extensions: %{code: "UNAUTHENTICATED"}},
	]
end
end
