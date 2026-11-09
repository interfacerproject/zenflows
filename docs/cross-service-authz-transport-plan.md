# PDP Transport + First DPP Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the already-built Zenflows PDP over an internal HTTP endpoint that re-verifies the user's signature itself, and make the DPP enforcement point call it to authorize its four write handlers (enforce now).

**Architecture:** Two seams across two repos under one ratified contract. In Zenflows (Elixir), a thin `Pdp.Transport` boundary parses a contract request + proof, re-verifies the proof with the existing `Restroom.verify_graphql`, sets `principal_proven` from that result alone, and delegates to the untouched pure `Pdp.decision/1`; a new `POST /authz/decide` Plug route wires it. In interfacer-dpp (Go), a new pure `internal/authz` package builds the request and interprets the response, a thin client POSTs it, and each write handler derives `binding.parent_id` from the stored DPP's `ProductID` and enforces `allow`/`deny`.

**Tech Stack:** Elixir (Plug, ExUnit, Jason, Zenroom via Restroom); Go (gin, net/http, encoding/json, testing, httptest).

**Spec:** `zenflows-authz-docs/docs/cross-service-authz-transport-design.md`

## Global Constraints

- No changes to `main`/`master` of gui or zenflows. All work on feature branches / draft PRs; no merge/deploy.
- Zenflows work on branch `feat/authz-pdp` (worktree `zenflows-pdp-local`); `src/zenflows/authz/pdp.ex` stays untouched (its 7/7 pure vectors must remain green).
- interfacer-dpp work on a branch stacked on `feat/authn-dpp-writes` (worktree `interfacer-dpp`); keep `go.mod` diff-free (no `-mod=mod` rewrites — revert with `git checkout go.mod` if it moves an indirect dep to direct).
- Action strings are fixed by the route and MUST match the PDP registry exactly: `dpp.spec.update`, `dpp.status.update`, `dpp.delete`, `dpp.attachment.delete`.
- Wire request shape is the contract request plus a `proof` block (spec §3.2): `request_id`, `action`, `principal.pk`, `binding.parent_id`, `proof.signature`, `proof.payload_b64` (base64 of the exact signed bytes).
- Contract response fields consumed on the Go side: `decision`, `reason_code`, `permission_epoch`, `obligations`, `request_id`, `policy_version`.
- Status codes: authentication failure `401` (existing `authenticateWrite`), authorization failure (deny / transport error / PDP unreachable) `403`, malformed PDP request `400`, rendered decision `200`.
- `principal_proven` is set ONLY from the transport's own re-verification result; a caller-supplied `principal_proven` MUST be ignored.
- `binding.parent_id` is the stored DPP's `ProductID`, read server-side from the database — NEVER from the client request body.
- Attribution: commit messages end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. PR descriptions end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Go heavy builds in the local ~1.9GB Docker VM use `-gcflags="all=-N -l"`; the DPP `zenflows-crypto` submodule must be checked out (`git submodule update --init internal/auth/zenflows-crypto`).

## Review Focus

- **`payload_b64` not valid base64** (Elixir transport) → `400`, never a crash and never a grant. Pinned in Task 1.
- **Caller supplies `principal_proven: true` with an invalid/absent proof** → must be ignored; decision is `deny` (unproven_subject). Pinned in Task 1.
- **PDP returns `allow` for an action the route did not fix** — the Go side must send only the route's action; a response for a different action is still just a decision, but `BuildRequest` must never echo a client-chosen action. Pinned in Task 3.
- **PDP unreachable / 5xx / timeout** (Go) → `Interpret` yields deny→`403`, fail closed. Pinned in Task 3 and Task 4.
- **Update changes `ProductID` in the body** — authz must check the STORED parent, so the client cannot relocate an object under a parent it controls to gain a write. The unit-testable half (the PDP request carries the `parent_id` the handler is *given*, not any client value) is pinned by `TestBuildRequestUsesRouteActionAndServerParent` in Task 3; that the handler *gives* it the stored `ProductID` (not the body's) is enforced by construction in Task 5's wiring and verified only by integration (needs Mongo) — called out in Task 5's note.

---

### Task 1: `Pdp.Transport.prepare/2` — pure parse + proof re-verification

**Files:**
- Create: `src/zenflows/authz/pdp/transport.ex`
- Test: `test/authz/pdp_transport.test.exs`

**Interfaces:**
- Consumes: nothing (pure).
- Produces: `Zenflows.Authz.Pdp.Transport.prepare(params :: map(), verify_fun :: (binary(), String.t(), String.t() -> :ok | {:error, term()})) :: {:ok, request :: map()} | {:error, {status :: 400, reason :: String.t()}}`. On success `request` is the contract request map with `"principal_proven"` set to a boolean computed solely from `verify_fun`.

- [ ] **Step 1: Write the failing tests**

Create `test/authz/pdp_transport.test.exs`:

```elixir
# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule ZenflowsTest.Authz.PdpTransport do
use ExUnit.Case, async: true

alias Zenflows.Authz.Pdp.Transport

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
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (from `zenflows-pdp-local`): `mix test test/authz/pdp_transport.test.exs`
Expected: FAIL — `Zenflows.Authz.Pdp.Transport` is undefined. If `mix test` cannot boot locally (no `_build`/DB), run the module through a standalone `elixir` script that defines the same asserts, as recorded in the project memory; the pure `prepare/2` needs no DB.

- [ ] **Step 3: Write the minimal implementation**

Create `src/zenflows/authz/pdp/transport.ex`:

```elixir
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
			{:ok, binding} <- req_map(params, "binding"),
			{:ok, _parent} <- req_string(binding, "parent_id"),
			{:ok, proof} <- req_map(params, "proof"),
			{:ok, sig} <- req_string(proof, "signature"),
			{:ok, payload_b64} <- req_string(proof, "payload_b64"),
			{:ok, payload} <- decode_b64(payload_b64) do
		proven? = verify_fun.(payload, sig, pk) == :ok

		request =
			params
			|> Map.put("action", action)
			|> Map.put("principal_proven", proven?)

		{:ok, request}
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
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/authz/pdp_transport.test.exs` (or the standalone `elixir` runner).
Expected: PASS (all cases).

- [ ] **Step 5: Commit**

```bash
git add src/zenflows/authz/pdp/transport.ex test/authz/pdp_transport.test.exs
git commit -m "feat(authz): pure Pdp.Transport.prepare — re-verify proof, set principal_proven

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `handle/2` + `POST /authz/decide` route

**Files:**
- Modify: `src/zenflows/authz/pdp/transport.ex` (add `handle/2`)
- Modify: `src/zenflows/web/router.ex` (add the route)
- Test: `test/authz/pdp_transport.test.exs` (add a malformed-body route test)

**Interfaces:**
- Consumes: `Transport.prepare/2` (Task 1); `Zenflows.Authz.Pdp.decision/1` (existing).
- Produces: `Zenflows.Authz.Pdp.Transport.handle(conn :: Plug.Conn.t(), opts :: keyword()) :: Plug.Conn.t()`. `opts[:verify_fun]` overrides the default verifier (tests); `opts[:decide_fun]` overrides `&Pdp.decision/1` (tests). Sends a JSON response: `400` on `prepare` error, else `200` with the contract response body.

- [ ] **Step 1: Write the failing test**

Append to `test/authz/pdp_transport.test.exs`:

```elixir
describe "handle/2" do
	import Plug.Test
	import Plug.Conn

	defp decoded(conn), do: Jason.decode!(conn.resp_body)

	# handle/2 reads conn.body_params (populated in production by the router's
	# existing Plug.Parsers JSON parser). Plug.Test does not run that parser, so
	# the tests set body_params directly — the parser itself is not under test.
	defp with_params(map) do
		%{conn(:post, "/authz/decide") | body_params: map}
	end

	test "malformed body (missing action) responds 400 without calling decide" do
		parent = self()
		decide = fn _ -> send(parent, :decided); %{} end
		conn =
			with_params(%{"principal" => %{"pk" => "P"}})
			|> Zenflows.Authz.Pdp.Transport.handle(verify_fun: fn _, _, _ -> :ok end, decide_fun: decide)

		assert conn.status == 400
		refute_receive :decided
	end

	test "a valid body passes the prepared request (principal_proven from verify) to decide and returns 200" do
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
			|> Zenflows.Authz.Pdp.Transport.handle(verify_fun: fn _, _, _ -> {:error, "no"} end, decide_fun: decide)

		assert conn.status == 200
		assert decoded(conn)["decision"] == "deny"
		assert_receive {:req, req}
		assert req["principal_proven"] == false
	end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/authz/pdp_transport.test.exs`
Expected: FAIL — `handle/2` undefined.

- [ ] **Step 3: Write the minimal implementation**

Add to `Zenflows.Authz.Pdp.Transport`:

```elixir
import Plug.Conn

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
```

Add the route to `src/zenflows/web/router.ex`, immediately before `forward "/api/file"`:

```elixir
post "/authz/decide" do
	Zenflows.Authz.Pdp.Transport.handle(conn)
end
```

(`conn.body_params` is populated by the existing `Plug.Parsers` JSON parser already in the pipeline; no new parser is needed.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/authz/pdp_transport.test.exs`
Expected: PASS. (The allow/deny-with-real-DB path is integration only; not asserted here.)

- [ ] **Step 5: Commit**

```bash
git add src/zenflows/authz/pdp/transport.ex src/zenflows/web/router.ex test/authz/pdp_transport.test.exs
git commit -m "feat(authz): expose PDP at POST /authz/decide via Pdp.Transport.handle

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Go `internal/authz` — pure request-builder + response-interpreter

**Files:**
- Create: `interfacer-dpp/internal/authz/authz.go`
- Test: `interfacer-dpp/internal/authz/authz_test.go`

**Interfaces:**
- Consumes: `*auth.Principal` from `internal/auth` (fields `Did`, `Pk`).
- Produces:
  - `type Proof struct { Signature string; PayloadB64 string }`
  - `type Request struct { RequestID string; Action string; Principal struct{ Pk string }; Binding struct{ ParentID string }; Proof Proof }` with JSON tags matching the wire shape.
  - `type Response struct { Decision, ReasonCode string; PermissionEpoch *int; Obligations map[string]any; RequestID, PolicyVersion string }`
  - `type Outcome struct { Allow bool; Status int; ReasonCode string }`
  - `func BuildRequest(requestID, action, parentID string, p *auth.Principal, proof Proof) Request`
  - `func Interpret(resp Response, transportErr error) Outcome` — `allow` ⇒ `{Allow:true, Status:200}`; anything else or any `transportErr` ⇒ `{Allow:false, Status:403, ReasonCode:...}`.

- [ ] **Step 1: Write the failing tests**

Create `interfacer-dpp/internal/authz/authz_test.go`:

```go
package authz

import (
	"errors"
	"testing"

	"github.com/interfacerproject/interfacer-dpp/internal/auth"
)

func TestBuildRequestUsesRouteActionAndServerParent(t *testing.T) {
	p := &auth.Principal{Did: "did:dyne:ifacer:PK", Pk: "PK"}
	req := BuildRequest("rid-1", "dpp.delete", "RESOURCE1", p,
		Proof{Signature: "SIG", PayloadB64: "cGF5"})

	if req.Action != "dpp.delete" {
		t.Fatalf("action: got %q want dpp.delete", req.Action)
	}
	if req.Binding.ParentID != "RESOURCE1" {
		t.Fatalf("parent: got %q want RESOURCE1", req.Binding.ParentID)
	}
	if req.Principal.Pk != "PK" {
		t.Fatalf("pk: got %q want PK", req.Principal.Pk)
	}
	if req.Proof.Signature != "SIG" || req.Proof.PayloadB64 != "cGF5" {
		t.Fatalf("proof not carried: %+v", req.Proof)
	}
	if req.RequestID != "rid-1" {
		t.Fatalf("request id: got %q", req.RequestID)
	}
}

func TestInterpretAllow(t *testing.T) {
	out := Interpret(Response{Decision: "allow", ReasonCode: "ok"}, nil)
	if !out.Allow || out.Status != 200 {
		t.Fatalf("allow: got %+v", out)
	}
}

func TestInterpretDenyIs403(t *testing.T) {
	out := Interpret(Response{Decision: "deny", ReasonCode: "not_controller"}, nil)
	if out.Allow || out.Status != 403 || out.ReasonCode != "not_controller" {
		t.Fatalf("deny: got %+v", out)
	}
}

func TestInterpretTransportErrorFailsClosed(t *testing.T) {
	out := Interpret(Response{}, errors.New("connection refused"))
	if out.Allow || out.Status != 403 {
		t.Fatalf("transport error must fail closed: got %+v", out)
	}
}

func TestInterpretUnknownDecisionFailsClosed(t *testing.T) {
	out := Interpret(Response{Decision: "maybe"}, nil)
	if out.Allow || out.Status != 403 {
		t.Fatalf("unknown decision must fail closed: got %+v", out)
	}
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (from `interfacer-dpp`, or in the Docker VM with `-gcflags="all=-N -l"`): `go test ./internal/authz/`
Expected: FAIL — package/types undefined.

- [ ] **Step 3: Write the minimal implementation**

Create `interfacer-dpp/internal/authz/authz.go`:

```go
// Package authz is the DPP enforcement point's client of the cross-service
// Policy Decision Point (zenflows docs/cross-service-authz-contract.md §4).
//
// BuildRequest and Interpret are pure so the request shape and the
// fail-closed decision mapping are unit-testable without a live PDP. The
// network call lives in client.go. The action is fixed by the route and the
// parent is derived server-side from the stored object by the caller — never
// taken from client payload (contract §3, deny.parent_from_binding_not_payload).
package authz

import "github.com/interfacerproject/interfacer-dpp/internal/auth"

// Proof carries the exact bytes the PEP verified (base64) and their signature,
// so the PDP re-verifies the user's own signature instead of trusting this
// service's assertion of identity (contract §4.3 property 2).
type Proof struct {
	Signature  string `json:"signature"`
	PayloadB64 string `json:"payload_b64"`
}

// Request is the contract request plus the proof block.
type Request struct {
	RequestID string `json:"request_id"`
	Action    string `json:"action"`
	Principal struct {
		Pk string `json:"pk"`
	} `json:"principal"`
	Binding struct {
		ParentID string `json:"parent_id"`
	} `json:"binding"`
	Proof Proof `json:"proof"`
}

// Response is the contract response rendered by the PDP.
type Response struct {
	Decision        string         `json:"decision"`
	ReasonCode      string         `json:"reason_code"`
	PermissionEpoch *int           `json:"permission_epoch"`
	Obligations     map[string]any `json:"obligations"`
	RequestID       string         `json:"request_id"`
	PolicyVersion   string         `json:"policy_version"`
}

// Outcome is what the handler enforces.
type Outcome struct {
	Allow      bool
	Status     int
	ReasonCode string
}

// BuildRequest assembles the wire request. action and parentID are supplied by
// the caller (route-fixed action; parent read from the stored object).
func BuildRequest(requestID, action, parentID string, p *auth.Principal, proof Proof) Request {
	var r Request
	r.RequestID = requestID
	r.Action = action
	r.Principal.Pk = p.Pk
	r.Binding.ParentID = parentID
	r.Proof = proof
	return r
}

// Interpret maps a PDP response (or a transport error) to an enforced outcome.
// Fail closed: only an explicit "allow" proceeds; everything else is 403.
func Interpret(resp Response, transportErr error) Outcome {
	if transportErr != nil {
		return Outcome{Allow: false, Status: 403, ReasonCode: "pdp_unreachable"}
	}
	if resp.Decision == "allow" {
		return Outcome{Allow: true, Status: 200, ReasonCode: resp.ReasonCode}
	}
	reason := resp.ReasonCode
	if reason == "" {
		reason = "denied"
	}
	return Outcome{Allow: false, Status: 403, ReasonCode: reason}
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `go test ./internal/authz/`
Expected: PASS. Confirm `go.mod` is unchanged (`git diff --stat go.mod` empty).

- [ ] **Step 5: Commit**

```bash
git add internal/authz/authz.go internal/authz/authz_test.go
git commit -m "feat(authz): pure PDP request-builder and fail-closed response-interpreter

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Go PDP client (`Client.Decide`)

**Files:**
- Create: `interfacer-dpp/internal/authz/client.go`
- Test: `interfacer-dpp/internal/authz/client_test.go`

**Interfaces:**
- Consumes: `Request`, `Response` (Task 3).
- Produces:
  - `type Client struct { BaseURL string; HTTP *http.Client }`
  - `func NewClientFromEnv() *Client` — reads `ZENFLOWS_PDP_URL`, default `http.Client` timeout 5s.
  - `func (c *Client) Decide(ctx context.Context, req Request) (Response, error)` — POSTs JSON to `BaseURL + "/authz/decide"`; a non-2xx status or decode failure is an error (so `Interpret` fails closed).

- [ ] **Step 1: Write the failing test**

Create `interfacer-dpp/internal/authz/client_test.go`:

```go
package authz

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/interfacerproject/interfacer-dpp/internal/auth"
)

func TestDecidePostsRequestAndParsesResponse(t *testing.T) {
	var gotPath string
	var gotReq Request
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		_ = json.NewDecoder(r.Body).Decode(&gotReq)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(Response{Decision: "allow", ReasonCode: "ok"})
	}))
	defer srv.Close()

	c := &Client{BaseURL: srv.URL, HTTP: srv.Client()}
	req := BuildRequest("rid", "dpp.delete", "R1",
		&auth.Principal{Pk: "PK"}, Proof{Signature: "S", PayloadB64: "cGF5"})
	resp, err := c.Decide(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if gotPath != "/authz/decide" {
		t.Fatalf("path: got %q", gotPath)
	}
	if gotReq.Action != "dpp.delete" || gotReq.Binding.ParentID != "R1" {
		t.Fatalf("server received wrong request: %+v", gotReq)
	}
	if resp.Decision != "allow" {
		t.Fatalf("decision: got %q", resp.Decision)
	}
}

func TestDecideNon2xxIsError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()

	c := &Client{BaseURL: srv.URL, HTTP: srv.Client()}
	_, err := c.Decide(context.Background(), BuildRequest("r", "dpp.delete", "R", &auth.Principal{Pk: "P"}, Proof{}))
	if err == nil {
		t.Fatal("expected an error on 5xx so Interpret fails closed")
	}
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `go test ./internal/authz/`
Expected: FAIL — `Client`/`Decide` undefined.

- [ ] **Step 3: Write the minimal implementation**

Create `interfacer-dpp/internal/authz/client.go`:

```go
package authz

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

// Client posts decision requests to the Zenflows PDP.
type Client struct {
	BaseURL string
	HTTP    *http.Client
}

// NewClientFromEnv reads ZENFLOWS_PDP_URL. The client is still returned when
// the env is empty; Decide then errors and Interpret fails closed to 403.
func NewClientFromEnv() *Client {
	return &Client{
		BaseURL: os.Getenv("ZENFLOWS_PDP_URL"),
		HTTP:    &http.Client{Timeout: 5 * time.Second},
	}
}

// Decide POSTs req to <BaseURL>/authz/decide and decodes the contract
// response. A missing base URL, a transport failure, a non-2xx status, or an
// undecodable body is returned as an error.
func (c *Client) Decide(ctx context.Context, req Request) (Response, error) {
	var zero Response
	if c.BaseURL == "" {
		return zero, fmt.Errorf("ZENFLOWS_PDP_URL not configured")
	}
	buf, err := json.Marshal(req)
	if err != nil {
		return zero, err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.BaseURL+"/authz/decide", bytes.NewReader(buf))
	if err != nil {
		return zero, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	res, err := c.HTTP.Do(httpReq)
	if err != nil {
		return zero, err
	}
	defer res.Body.Close()

	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return zero, fmt.Errorf("pdp returned status %d", res.StatusCode)
	}
	var out Response
	if err := json.NewDecoder(res.Body).Decode(&out); err != nil {
		return zero, err
	}
	return out, nil
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `go test ./internal/authz/`
Expected: PASS (all four tests from Tasks 3–4).

- [ ] **Step 5: Commit**

```bash
git add internal/authz/client.go internal/authz/client_test.go
git commit -m "feat(authz): PDP HTTP client, fail-closed on unreachable/non-2xx

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: `authorizeWrite` helper + wire the four DPP write handlers

**Files:**
- Create: `interfacer-dpp/internal/handler/authz.go`
- Modify: `interfacer-dpp/internal/handler/handler.go` (UpdateDPP ~154, DeleteDPP ~195, UpdateDPPStatus ~481, DeleteAttachment ~677)
- Test: `interfacer-dpp/internal/handler/authz_test.go`

**Interfaces:**
- Consumes: `authz.NewClientFromEnv`, `authz.BuildRequest`, `authz.Interpret`, `authz.Proof` (Tasks 3–4); `*auth.Principal` from `authenticateWrite`.
- Produces: `func authorizeWrite(c *gin.Context, principal *auth.Principal, action, parentID, payloadB64 string) bool` — calls the PDP; on `allow` returns `true`; otherwise writes `403` (`{"error","reason"}`), aborts, returns `false`. Package-level `var pdpClient = authz.NewClientFromEnv()` with a seam so the test can swap in an `httptest`-backed client.

- [ ] **Step 1: Write the failing test**

Create `interfacer-dpp/internal/handler/authz_test.go`:

```go
package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/interfacerproject/interfacer-dpp/internal/auth"
	"github.com/interfacerproject/interfacer-dpp/internal/authz"
)

func testCtx() (*gin.Context, *httptest.ResponseRecorder) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodDelete, "/dpp/01/", nil)
	return c, w
}

func TestAuthorizeWriteAllowProceeds(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(authz.Response{Decision: "allow", ReasonCode: "ok"})
	}))
	defer srv.Close()
	old := pdpClient
	pdpClient = &authz.Client{BaseURL: srv.URL, HTTP: srv.Client()}
	defer func() { pdpClient = old }()

	c, w := testCtx()
	ok := authorizeWrite(c, &auth.Principal{Pk: "PK"}, "dpp.delete", "R1", "cGF5")
	if !ok || c.IsAborted() || w.Code != http.StatusOK {
		t.Fatalf("allow should proceed: ok=%v aborted=%v code=%d", ok, c.IsAborted(), w.Code)
	}
}

func TestAuthorizeWriteDenyIs403(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(authz.Response{Decision: "deny", ReasonCode: "not_controller"})
	}))
	defer srv.Close()
	old := pdpClient
	pdpClient = &authz.Client{BaseURL: srv.URL, HTTP: srv.Client()}
	defer func() { pdpClient = old }()

	c, w := testCtx()
	ok := authorizeWrite(c, &auth.Principal{Pk: "PK"}, "dpp.delete", "R1", "cGF5")
	if ok || !c.IsAborted() || w.Code != http.StatusForbidden {
		t.Fatalf("deny must be 403+abort: ok=%v aborted=%v code=%d", ok, c.IsAborted(), w.Code)
	}
}

func TestAuthorizeWriteUnreachableFailsClosed(t *testing.T) {
	old := pdpClient
	pdpClient = &authz.Client{BaseURL: "", HTTP: http.DefaultClient} // empty URL => error
	defer func() { pdpClient = old }()

	c, w := testCtx()
	ok := authorizeWrite(c, &auth.Principal{Pk: "PK"}, "dpp.delete", "R1", "cGF5")
	if ok || w.Code != http.StatusForbidden {
		t.Fatalf("unreachable PDP must fail closed to 403: ok=%v code=%d", ok, w.Code)
	}
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `go test ./internal/handler/`
Expected: FAIL — `authorizeWrite`/`pdpClient` undefined.

- [ ] **Step 3: Write the minimal implementation**

Create `interfacer-dpp/internal/handler/authz.go`:

```go
package handler

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/interfacerproject/interfacer-dpp/internal/auth"
	"github.com/interfacerproject/interfacer-dpp/internal/authz"
)

// pdpClient is the enforcement point's client of the cross-service PDP. It is a
// package var so tests can point it at an httptest server.
var pdpClient = authz.NewClientFromEnv()

func newRequestID() string {
	var b [8]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}

// authorizeWrite asks the PDP whether principal may perform action on the
// resource parentID (the stored DPP's ProductID, derived server-side).
// payloadB64 is the base64 of the exact bytes the PEP already verified, so the
// PDP re-verifies the user's own signature. On allow it returns true; on deny
// or any transport error it writes 403, aborts, and returns false (fail
// closed). This is authorization; authenticateWrite already proved identity.
func authorizeWrite(c *gin.Context, principal *auth.Principal, action, parentID, payloadB64 string) bool {
	sig := c.Request.Header.Get("did-sign")
	req := authz.BuildRequest(newRequestID(), action, parentID, principal,
		authz.Proof{Signature: sig, PayloadB64: payloadB64})

	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	resp, err := pdpClient.Decide(ctx, req)
	out := authz.Interpret(resp, err)
	if !out.Allow {
		log.Printf("write authz denied: reason=%s action=%s parent=%s route=%s",
			out.ReasonCode, action, parentID, c.FullPath())
		c.JSON(http.StatusForbidden, gin.H{
			"error":  "not authorized for this operation",
			"reason": out.ReasonCode,
		})
		c.Abort()
		return false
	}
	return true
}
```

Now wire each handler. The pattern: capture the principal from `authenticateWrite`, ensure the stored DPP is loaded, then call `authorizeWrite` with `dpp.ProductID` and the base64 of the signed bytes.

**UpdateDPP** (`handler.go` ~154). The signed bytes are the request body, so `payloadB64 = base64(body)`. Load the stored DPP before updating:

```go
	body, principal, ok := authenticateWrite(c, id, false)
	if !ok {
		return
	}

	dppCollection, err := getCollection()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to connect to database"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Derive the authorization parent from the STORED object, never the body.
	var stored model.DigitalProductPassport
	if err := dppCollection.FindOne(ctx, bson.M{"_id": objId}).Decode(&stored); err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"error": "Document not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error retrieving document"})
		return
	}
	if !authorizeWrite(c, principal, "dpp.spec.update", stored.ProductID,
		b64.StdEncoding.EncodeToString(body)) {
		return
	}
```

(Add `b64 "encoding/base64"` to `handler.go` imports if not present. The remaining `json.Unmarshal(body, &dpp)` + `UpdateOne` stay as-is.)

**DeleteDPP** (`handler.go` ~195). Signed bytes are the id string, so `payloadB64 = base64(id)`. Load the DPP before deleting:

```go
	_, principal, ok := authenticateWrite(c, id, true)
	if !ok {
		return
	}

	dppCollection, err := getCollection()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to connect to database"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var stored model.DigitalProductPassport
	if err := dppCollection.FindOne(ctx, bson.M{"_id": objId}).Decode(&stored); err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"error": "Document not found to delete"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error retrieving document"})
		return
	}
	if !authorizeWrite(c, principal, "dpp.delete", stored.ProductID,
		b64.StdEncoding.EncodeToString([]byte(id))) {
		return
	}
	// existing DeleteOne follows
```

**UpdateDPPStatus** (`handler.go` ~481). Signed bytes are the body (`raw`). It already loads `current` via `FindOne` for transition validation — add the authz call right after that decode succeeds:

```go
	raw, principal, ok := authenticateWrite(c, id, false)
	...
	// after: err = dppCollection.FindOne(ctx, bson.M{"_id": objId}).Decode(&current)  (success)
	if !authorizeWrite(c, principal, "dpp.status.update", current.ProductID,
		b64.StdEncoding.EncodeToString(raw)) {
		return
	}
	// existing transition validation follows
```

**DeleteAttachment** (`handler.go` ~677). Signed bytes are the DPP id string. It already loads `dpp` via `FindOne` — add the authz call right after that decode succeeds:

```go
	_, principal, ok := authenticateWrite(c, id, true)
	...
	// after: err = dppCollection.FindOne(ctx, bson.M{"_id": objId}).Decode(&dpp)  (success)
	if !authorizeWrite(c, principal, "dpp.attachment.delete", dpp.ProductID,
		b64.StdEncoding.EncodeToString([]byte(id))) {
		return
	}
	// existing attachment-removal loop follows
```

**Note (integration-only property):** the `authorizeWrite` unit tests take `parentID` as an argument, so they verify fail-closed enforcement but not that the handler derives `parentID` from the *stored* DPP rather than the client body. That derivation is enforced by construction (each handler reads `stored.ProductID` / `current.ProductID` / `dpp.ProductID` from a `FindOne` and never from the unmarshalled body) and is verifiable only against a live Mongo — record it as an integration check in the PR, do not fake a unit test for it.

- [ ] **Step 4: Run the tests to verify they pass, then build/vet the package**

Run: `go test ./internal/handler/` → Expected: PASS (the three `authorizeWrite` tests).
Run: `go vet ./... && go build ./...` (Docker VM: prefix env `GOFLAGS=-gcflags=all=-N\ -l`) → Expected: clean. Confirm `git diff --stat go.mod` is empty.

- [ ] **Step 5: Commit**

```bash
git add internal/handler/authz.go internal/handler/handler.go internal/handler/authz_test.go
git commit -m "feat(authz): enforce PDP decision on the four DPP write handlers

Parent derived server-side from the stored DPP ProductID; action fixed by
the route; deny or PDP error -> 403 (authn stays 401). Enforce now.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Config wiring + draft PRs

**Files:**
- Modify: `interfacer-dpp/.env.example` (document `ZENFLOWS_PDP_URL`)
- Modify: `interfacer-dpp/cmd/main/main.go` (only if it pre-validates env; routes are unchanged)

- [ ] **Step 1: Document the new env**

Add to `interfacer-dpp/.env.example`:

```
# Base URL of the Zenflows cross-service PDP (POST {URL}/authz/decide).
# Required for DPP write authorization; if unset, all writes fail closed (403).
ZENFLOWS_PDP_URL=http://localhost:8000
```

- [ ] **Step 2: Build once more and run the full suites**

Run (interfacer-dpp): `go test ./... && go build ./...`
Run (zenflows-pdp-local): `mix test test/authz/` (or the standalone runners per project memory).
Expected: all green; `pdp.test.exs` still 7/7.

- [ ] **Step 3: Commit the env doc**

```bash
git add .env.example
git commit -m "docs(authz): document ZENFLOWS_PDP_URL for DPP write authorization

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 4: Push branches and open/refresh draft PRs**

- Push `feat/authz-pdp` (zenflows) and refresh draft PR #80 to cover the transport (`transport.ex`, router route, transport tests).
- Push the interfacer-dpp branch (stacked on `feat/authn-dpp-writes`) and open/refresh the DPP draft PR (#7) to cover `internal/authz`, `authorizeWrite`, the wired handlers, and the env doc.
- Push `docs/cross-service-authz` (zenflows-authz-docs) with the design + plan docs.
- Each PR body: what shipped, the trust model (PDP re-verifies the user's signature; no service credential; internal endpoint; enforce now), the §5 honest limitations verbatim, and the verification method used. End each PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

---

## Notes for the executor

- Run Elixir from the `zenflows-pdp-local` worktree, Go from `interfacer-dpp`. Never `cd` between worktrees mid-command; use absolute paths.
- If `mix test` cannot boot (no local `_build`/DB), the pure `prepare/2` and the `handle/2` 400 path run under a standalone `elixir` script with `Mix.install([:jason, :plug])` and the relevant module source, as recorded in project memory; the allow/deny-with-DB path is integration-only and is not asserted locally.
- Keep `internal/auth` (authentication floor) and `internal/authz` (authorization) as separate packages — do not merge them.
