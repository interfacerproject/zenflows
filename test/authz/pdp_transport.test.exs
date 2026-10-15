# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule ZenflowsTest.Authz.PdpTransport do
use ExUnit.Case, async: true

import Plug.Test

alias Zenflows.Authz.Pdp.Transport

# handle/2 reads conn.body_params (populated in production by the router's
# existing Plug.Parsers JSON parser). Plug.Test does not run that parser, so
# the tests set body_params directly — the parser itself is not under test.
defp with_params(map) do
	%{conn(:post, "/authz/decide") | body_params: map}
end

defp decoded(conn), do: Jason.decode!(conn.resp_body)

# A valid request body as decoded from JSON (string keys), with a proof
# block whose payload is valid base64. The stub verify_fun decides the
# outcome, so no zenroom is needed here.
defp body() do
	%{
		"request_id" => "req-1",
		"action" => "dpp.spec.update",
		"principal" => %{"pk" => "PKPKPK"},
		"binding" => %{"parent_id" => "RESOURCE1"},
		"proof" => %{"signature" => "SIGSIG", "payload_b64" => Base.encode64("the-signed-bytes")}
	}
end

defp ok_verify(_payload, _sig, _pk), do: :ok
defp bad_verify(_payload, _sig, _pk), do: {:error, "nope"}

test "a valid body with a passing proof sets principal_proven true and carries the fields" do
	assert {:ok, req} = Transport.prepare(body(), &ok_verify/3)
	assert req["principal_proven"] == true
	assert req["action"] == "dpp.spec.update"
	assert get_in(req, ["principal", "pk"]) == "PKPKPK"
	assert get_in(req, ["binding", "parent_id"]) == "RESOURCE1"
	assert req["request_id"] == "req-1"
end

test "a failing proof sets principal_proven false (no error, decision stays deny downstream)" do
	assert {:ok, req} = Transport.prepare(body(), &bad_verify/3)
	assert req["principal_proven"] == false
end

test "a caller-supplied principal_proven is ignored and recomputed from the proof" do
	lying = Map.put(body(), "principal_proven", true)
	assert {:ok, req} = Transport.prepare(lying, &bad_verify/3)
	assert req["principal_proven"] == false
end

test "the exact signed bytes are decoded from payload_b64 and passed to verify_fun" do
	parent = self()
	spy = fn payload, sig, pk ->
		send(parent, {:verify, payload, sig, pk}); :ok
	end
	assert {:ok, _} = Transport.prepare(body(), spy)
	assert_receive {:verify, "the-signed-bytes", "SIGSIG", "PKPKPK"}
end

for field <- ~w[action principal binding proof] do
	@field field
	test "missing #{field} is a 400" do
		assert {:error, {400, _}} = Transport.prepare(Map.delete(body(), @field), &ok_verify/3)
	end
end

test "a non-base64 payload_b64 is a 400, not a crash" do
	bad = put_in(body(), ["proof", "payload_b64"], "!!!not base64!!!")
	assert {:error, {400, _}} = Transport.prepare(bad, &ok_verify/3)
end

test "a non-string action is a 400" do
	assert {:error, {400, _}} = Transport.prepare(Map.put(body(), "action", 7), &ok_verify/3)
end

test "handle/2: malformed body (missing action) responds 400 without calling decide" do
	parent = self()
	decide = fn _ -> send(parent, :decided); %{} end
	conn =
		with_params(%{"principal" => %{"pk" => "P"}})
		|> Transport.handle(verify_fun: fn _, _, _ -> :ok end, decide_fun: decide)

	assert conn.status == 400
	refute_receive :decided
end

test "handle/2: a valid body passes the prepared request (principal_proven from verify) to decide and returns 200" do
	parent = self()
	decide = fn req ->
		send(parent, {:req, req})
		%{"decision" => "deny", "reason_code" => "not_controller",
			"permission_epoch" => 1, "obligations" => %{}}
	end
	conn =
		with_params(%{
			"request_id" => "r1", "action" => "dpp.delete",
			"principal" => %{"pk" => "P"}, "binding" => %{"parent_id" => "R1"},
			"proof" => %{"signature" => "S", "payload_b64" => Base.encode64("x")}
		})
		|> Transport.handle(verify_fun: fn _, _, _ -> {:error, "no"} end, decide_fun: decide)

	assert conn.status == 200
	assert decoded(conn)["decision"] == "deny"
	assert_receive {:req, req}
	assert req["principal_proven"] == false
end
end
