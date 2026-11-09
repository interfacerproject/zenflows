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

defmodule ZenflowsTest.Authz.ExecutionContext do
use ExUnit.Case, async: true

alias Zenflows.Authz.ExecutionContext, as: Ctx
alias Zenflows.VF.Person

test "from_resolution: person when req_user is set" do
	per = %Person{id: Zenflows.DB.ID.gen()}
	ctx = Ctx.from_resolution(%{context: %{req_user: per, request_id: "r1"}})
	assert %Ctx{principal: ^per, via: :gql, request_id: "r1"} = ctx
	assert Ctx.actor_id(ctx) == per.id
end

test "from_resolution: anonymous otherwise, with a generated request id" do
	ctx = Ctx.from_resolution(%{context: %{}})
	assert %Ctx{principal: :anonymous, via: :gql, request_id: rid} = ctx
	assert byte_size(rid) == 26
	assert Ctx.actor_id(ctx) == nil
end

test "admin_key: service principal only when calls are authenticated" do
	ctx = Ctx.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})
	assert %Ctx{principal: {:service, :admin_key, actions}, via: :admin_key} = ctx
	assert MapSet.member?(actions, "person.create")
	refute MapSet.member?(actions, "resource.update")

	assert %Ctx{principal: :anonymous} =
		Ctx.admin_key(%{context: %{authenticate_calls?: false}})
end

test "service: fixed action sets" do
	assert %Ctx{principal: {:service, :import, a}, via: :import, request_id: "r"} =
		Ctx.service(:import, "r")
	assert MapSet.member?(a, "relationship.grant")
	assert %Ctx{principal: {:service, :migration, m}} = Ctx.service(:migration, nil)
	assert MapSet.member?(m, "organization.create")
	assert_raise FunctionClauseError, fn -> Ctx.service(:admin_key, nil) end
end
end
