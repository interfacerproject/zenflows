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

defmodule ZenflowsTest.Web.GQLContext do
use ExUnit.Case, async: true
import Plug.Test
import Plug.Conn

alias Zenflows.Web.MW.GQLContext

defp ctx(conn), do: GQLContext.call(conn, []).private.absinthe.context

test "valid request id header is kept" do
	conn = conn(:post, "/api") |> put_req_header("zenflows-request-id", "abc-123_X")
	assert %{request_id: "abc-123_X"} = ctx(conn)
end

test "invalid request id header is ignored" do
	conn = conn(:post, "/api") |> put_req_header("zenflows-request-id", "bad id;drop")
	refute Map.has_key?(ctx(conn), :request_id)
end
end
