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

defmodule Zenflows.Authz.Pdp.Transport do
@moduledoc """
Wire boundary for the cross-service PDP (contract §4, transport §3 of
`cross-service-authz-transport-design.md`).

`prepare/2` is pure: it validates a decoded request body and sets
`principal_proven` **solely** from an independent re-verification of the
user's signature (never from a caller-supplied field), honoring contract
§4.3 property 2.  The real verifier is `Restroom.verify_graphql/3`,
injected so the pure logic is unit-testable without zenroom.

`handle/2` is the Plug entrypoint used by the router: it runs `prepare/2`
with the real verifier and delegates the prepared request to the pure
`Zenflows.Authz.Pdp.decision/1`.
"""

import Plug.Conn

alias Zenflows.Authz.Pdp
alias Zenflows.Restroom

@type verify_fun :: (binary(), String.t(), String.t() -> :ok | {:error, term()})

@doc """
Validate a decoded request body and attach `principal_proven` from a
re-verification of the proof.  Returns `{:ok, request}` or
`{:error, {400, reason}}`.
"""
@spec prepare(map(), verify_fun()) :: {:ok, map()} | {:error, {400, String.t()}}
def prepare(params, verify_fun) when is_map(params) do
	with {:ok, action} <- req_string(params, "action"),
			{:ok, principal} <- req_map(params, "principal"),
			{:ok, pk} <- req_string(principal, "pk"),
			{:ok, proof} <- req_map(params, "proof"),
			{:ok, sig} <- req_string(proof, "signature"),
			{:ok, payload_b64} <- req_string(proof, "payload_b64"),
			{:ok, payload} <- decode_b64(payload_b64),
			:ok <- require_binding(params, action) do
		proven? = verify_fun.(payload, sig, pk) == :ok

		request =
			params
			|> Map.put("action", action)
			|> Map.put("principal_proven", proven?)

		{:ok, request}
	end
end

# A resource-control action is evaluated against the parent named in its
# binding; the binding must be present.  An identity-proof action (feedback)
# has no resource parent, so a binding is not required.
defp require_binding(params, action) do
	if Zenflows.Authz.Pdp.capability(action) == :resource_control do
		with {:ok, binding} <- req_map(params, "binding"),
				{:ok, _parent} <- req_string(binding, "parent_id") do
			:ok
		end
	else
		:ok
	end
end

defp req_string(map, key) do
	case Map.get(map, key) do
		v when is_binary(v) and v != "" -> {:ok, v}
		_ -> {:error, {400, "missing or invalid #{key}"}}
	end
end

defp req_map(map, key) do
	case Map.get(map, key) do
		v when is_map(v) -> {:ok, v}
		_ -> {:error, {400, "missing or invalid #{key}"}}
	end
end

defp decode_b64(s) do
	case Base.decode64(s) do
		{:ok, bin} -> {:ok, bin}
		:error -> {:error, {400, "payload_b64 is not valid base64"}}
	end
end

@doc """
Plug entrypoint for `POST /authz/decide`.  Reads the JSON body (already
decoded by the router's parsers when present), runs `prepare/2`, and
delegates to the PDP.  Fail closed: a prepare error is a 400; every
rendered decision is a 200 with the contract response (allow and deny
alike — `decision/1` already rescues internal failures to a deny).
"""
@spec handle(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
def handle(conn, opts \\ []) do
	verify_fun = Keyword.get(opts, :verify_fun, &Restroom.verify_graphql/3)
	decide_fun = Keyword.get(opts, :decide_fun, &Pdp.decision/1)

	case prepare(conn.body_params, verify_fun) do
		{:ok, request} ->
			send_json(conn, 200, decide_fun.(request))

		{:error, {status, reason}} ->
			send_json(conn, status, %{"error" => reason})
	end
end

defp send_json(conn, status, body) do
	conn
	|> put_resp_content_type("application/json")
	|> send_resp(status, Jason.encode!(body))
end
end
