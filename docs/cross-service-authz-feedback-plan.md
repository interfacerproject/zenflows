# Feedback PEP (subject-proving) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `interfacer-feedback-service` enforce the authenticated user's *proven* identity (resolved by the Zenflows PDP from the signing key) instead of the self-asserted `x-user-id` header, closing a live impersonation gap on its four write endpoints.

**Architecture:** The PDP (Zenflows, Elixir) gains a `feedback.*` action family whose decision is pure identity-proof: it re-verifies the signature and returns the proven `Person.id` as a response `subject`. The feedback service (Go/Gin) gains an `internal/authz` client and an `AuthzMiddleware` that runs after the existing authn middleware on the four write routes, calls the PDP, and sets `user_ulid` to the proven subject (overriding `x-user-id`). Feedback's existing ownership SQL is unchanged and becomes sound on a proven id.

**Tech Stack:** Elixir 1.14.5/OTP-25 (Zenflows), Go 1.25.0 (feedback), Gin, EdDSA-over-Zenroom signatures, shared `contract.json` vectors.

**Spec:** `docs/cross-service-authz-feedback-design.md`

## Global Constraints

- **No `main`/`master` changes to gui or zenflows.** Feature branches + draft PRs only; no merge/deploy. Feedback service likewise uses a feature branch + draft PR.
- **Branches:** zenflows PDP work on `feat/authz-feedback-pdp` (cut from `feat/authz-pdp`); feedback work on `feat/authz-pep` (cut from `main`); this plan + design on `docs/authz-feedback`.
- **Attribution:** commit messages end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. PR descriptions end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **Local toolchain (same as the DPP/transport slice):**
  - Go: no local toolchain — run in Docker `golang:1.24-bullseye` with `-gcflags="all=-N -l"` and cache volumes `dpp-gocache`/`dpp-gomod` mounted; module path `github.com/interfacerproject/interfacer-feedback-service`. Feedback's `go test ./...` does not need zenroom for the tasks below (all PDP calls are `httptest` stubs; no test invokes `IsAuth`/`VerifyDid`).
  - Elixir: mise `1.14.5-otp-25`. Full `mix test` is not runnable locally (deps/Postgres); run PDP unit checks via **standalone ExUnit runners** that `Code.require_file/1` the real source and iterate `contract.json`, exactly as the transport slice did. For Plug, pin `{:plug, "1.14.2"}` and `{:jason, "1.4.0"}` in `Mix.install` (latest Plug won't compile on 1.14.5).
- **Fail closed everywhere.** Authentication failure stays `401`; authorization failure (deny, unresolved key, PDP error/unreachable, empty subject) is `403`.
- **Zenroom is never exercised in unit tests.** PDP re-verification uses an injected `verify_fun` stub; feedback uses `httptest` PDP stubs.

## Review Focus

- **Proven subject must override a lying/absent `x-user-id`.** The whole slice exists for this; a test must set `x-user-id` to a victim and assert the write is attributed to the PDP-returned subject. (Task 5.)
- **An `allow` with an empty `subject` must fail closed to 403**, not proceed — a PDP that grants but could not resolve the key must never become a write. (Task 3 `Interpret`, Task 5 middleware.)
- **The transport must accept a feedback request with no `binding.parent_id` (not 400), while DPP requests still require it.** The relaxation must be scoped to the `:proven_identity` capability. (Task 2.)
- **Removing the "missing `x-user-id` → 401" guard must not weaken the signature authn floor** — unsigned/badly-signed writes must still get 401 from `AuthMiddleware`. (Task 6; verified by code-read + the retained signature checks.)
- **`AuthzMiddleware` must re-read the exact bytes the client signed** (the raw body, including the literal `{}` on deletes) and restore the body so the create handlers can still read it. A consuming read without restore breaks creates. (Task 5.)

---

### Task 1: PDP — feedback action family + subject in `decide/2`

**Repo/branch:** zenflows, `feat/authz-feedback-pdp` (cut from `feat/authz-pdp`).

**Files:**
- Modify: `src/zenflows/authz/pdp.ex` (the `@actions` map; a new `capability/1`; a `:proven_identity` branch in `decide/2`)
- Modify: `docs/cross-service-authz/contract.json` (three feedback vectors)
- Test: standalone ExUnit runner (below) over `contract.json`

**Interfaces:**
- Produces: `Zenflows.Authz.Pdp.capability(action :: String.t()) :: atom() | nil`; `decide/2` returns, for a `:proven_identity` action with a resolved `facts["subject"]`, an `allow` response carrying `"subject"`.
- Consumes: the existing `decide/2`, `allow/2`, `deny/3`, `@actions`.

- [ ] **Step 1: Add the three feedback vectors to `contract.json`**

Append to the `vectors` array in `docs/cross-service-authz/contract.json`:

```json
    {
      "name": "contract.allow.feedback_proven_identity_carries_subject",
      "layer": "contract",
      "doc": "A proven key that resolves to a Person: a feedback write is allowed and the response carries the proven subject (Person.id). No resource control is consulted.",
      "input": {
        "request_id": "01J0REQ0000000000000000F001",
        "principal": { "pk": "pkAlice" },
        "action": "feedback.review.create"
      },
      "facts": { "principal_proven": true, "subject": "01PERSONALICE" },
      "expect": {
        "decision": "allow",
        "reason_code": "ok",
        "permission_epoch": null,
        "obligations": {},
        "subject": "01PERSONALICE"
      }
    },
    {
      "name": "contract.deny.feedback_unproven_subject",
      "layer": "contract",
      "doc": "The signature did not verify: a feedback write is denied before any resolution, with the shared unproven_subject reason.",
      "input": {
        "request_id": "01J0REQ0000000000000000F002",
        "principal": { "pk": "pkAlice" },
        "action": "feedback.comment.create"
      },
      "facts": { "principal_proven": false, "subject": null },
      "expect": {
        "decision": "deny",
        "reason_code": "unproven_subject",
        "permission_epoch": null,
        "obligations": {}
      }
    },
    {
      "name": "contract.deny.feedback_key_not_resolved",
      "layer": "contract",
      "doc": "The signature verified but the key resolves to no registered Person: deny, never a grant without a subject.",
      "input": {
        "request_id": "01J0REQ0000000000000000F003",
        "principal": { "pk": "pkGhost" },
        "action": "feedback.review.delete"
      },
      "facts": { "principal_proven": true, "subject": null },
      "expect": {
        "decision": "deny",
        "reason_code": "principal_not_resolved",
        "permission_epoch": null,
        "obligations": {}
      }
    }
```

- [ ] **Step 2: Write the standalone runner and watch it fail**

Write `/tmp/fb_decide_runner.exs` (scratch; not committed):

```elixir
Code.require_file("src/zenflows/authz/pdp.ex")
alias Zenflows.Authz.Pdp

contract =
  "docs/cross-service-authz/contract.json" |> File.read!() |> Jason.decode!()

fb =
  Enum.filter(contract["vectors"], fn v ->
    String.contains?(v["name"], "feedback")
  end)

results =
  for v <- fb do
    got = Pdp.decide(v["input"], v["facts"])
    ok = got == v["expect"]
    IO.puts("#{if ok, do: "PASS", else: "FAIL"}  #{v["name"]}")
    unless ok, do: IO.puts("  got:      #{inspect(got)}\n  expected: #{inspect(v["expect"])}")
    ok
  end

if Enum.all?(results), do: IO.puts("\nALL #{length(results)} GREEN"),
  else: (IO.puts("\nRED"); System.halt(1))
```

Run (mise Elixir, from the `zenflows` worktree root; `Jason` is a project dep so run inside the app's deps path, or add `Mix.install([{:jason, "1.4.0"}])` as the first line if running bare):
`elixir /tmp/fb_decide_runner.exs`
Expected: **RED** — the three feedback vectors FAIL because `decide/2` hits `unknown_action` for the allow case (the `feedback.*` actions are not yet in `@actions`).

- [ ] **Step 3: Add the feedback actions and a `capability/1` reader**

In `src/zenflows/authz/pdp.ex`, extend `@actions`:

```elixir
@actions %{
	"dpp.create" => :resource_control,
	"dpp.spec.update" => :resource_control,
	"dpp.status.update" => :resource_control,
	"dpp.delete" => :resource_control,
	"dpp.attachment.add" => :resource_control,
	"dpp.attachment.delete" => :resource_control,
	"dpp.file.upload" => :resource_control,
	"wallet.points.issue" => :resource_control,
	"feedback.review.create" => :proven_identity,
	"feedback.review.delete" => :proven_identity,
	"feedback.comment.create" => :proven_identity,
	"feedback.comment.delete" => :proven_identity
}
```

Add, next to `actions/0`:

```elixir
@doc "The capability an action requires, or nil if the action has no rule."
@spec capability(String.t()) :: atom() | nil
def capability(action), do: Map.get(@actions, action)
```

- [ ] **Step 4: Add the `:proven_identity` branch to `decide/2`**

In `decide/2`, extend the `case Map.fetch!(@actions, action)` with a second clause:

```elixir
			case Map.fetch!(@actions, action) do
				:resource_control ->
					if facts["controls_parent"] == true,
						do: allow(epoch, facts["obligations"] || %{}),
						else: deny("not_controller", epoch, %{})

				:proven_identity ->
					case facts["subject"] do
						nil -> deny("principal_not_resolved", epoch, %{})
						sub -> allow(epoch, facts["obligations"] || %{}) |> Map.put("subject", sub)
					end
			end
```

(The earlier `facts["principal_proven"] != true -> deny("unproven_subject", …)` guard already covers the unproven case for every capability.)

- [ ] **Step 5: Run the runner and watch it pass**

Run: `elixir /tmp/fb_decide_runner.exs`
Expected: **ALL 3 GREEN**. The allow vector returns `subject`; unproven → `unproven_subject`; resolved-nil → `principal_not_resolved`.

- [ ] **Step 6: Commit**

```bash
git add src/zenflows/authz/pdp.ex docs/cross-service-authz/contract.json
git commit -m "feat(authz): feedback action family + proven subject in PDP decision

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: PDP — resolve subject in `load_facts/1` + relax transport binding for feedback

**Repo/branch:** zenflows, `feat/authz-feedback-pdp`.

**Files:**
- Modify: `src/zenflows/authz/pdp.ex` (`load_facts/1` early branch for `:proven_identity`)
- Modify: `src/zenflows/authz/pdp/transport.ex` (`prepare/2`: binding required only for `:resource_control`)
- Test: standalone ExUnit runner for `prepare/2` (below)

**Interfaces:**
- Consumes: `Zenflows.Authz.Pdp.capability/1` (Task 1), the existing `resolve_principal/1`.
- Produces: `prepare/2` accepts a feedback request (no `binding`) as `{:ok, request}`; `load_facts/1` returns `%{"principal_proven" => _, "subject" => person_id | nil}` for `:proven_identity` actions.

- [ ] **Step 1: Write the transport runner and watch it fail**

Write `/tmp/fb_prepare_runner.exs` (scratch):

```elixir
Mix.install([{:plug, "1.14.2"}, {:jason, "1.4.0"}])
Code.require_file("src/zenflows/authz/pdp.ex")
Code.require_file("src/zenflows/authz/pdp/transport.ex")
alias Zenflows.Authz.Pdp.Transport

ok_verify = fn _p, _s, _pk -> :ok end

feedback_req = %{
  "request_id" => "r1",
  "action" => "feedback.review.create",
  "principal" => %{"pk" => "pkAlice"},
  "proof" => %{"signature" => "SIG", "payload_b64" => Base.encode64("{}")}
}

dpp_req = %{
  "request_id" => "r2",
  "action" => "dpp.delete",
  "principal" => %{"pk" => "pkAlice"},
  "proof" => %{"signature" => "SIG", "payload_b64" => Base.encode64("x")}
}

case Transport.prepare(feedback_req, ok_verify) do
  {:ok, req} ->
    IO.puts(if req["principal_proven"] == true, do: "PASS feedback-no-binding-ok", else: "FAIL proven flag")
  other -> IO.puts("FAIL feedback-no-binding: #{inspect(other)}")
end

case Transport.prepare(dpp_req, ok_verify) do
  {:error, {400, _}} -> IO.puts("PASS dpp-still-requires-binding")
  other -> IO.puts("FAIL dpp-binding: #{inspect(other)}")
end
```

Run: `elixir /tmp/fb_prepare_runner.exs`
Expected: **RED** — `feedback-no-binding-ok` FAILs because `prepare/2` currently returns `{:error, {400, "missing or invalid binding"}}` for any request without `binding`.

- [ ] **Step 2: Relax `prepare/2` to require binding only for resource-control actions**

In `src/zenflows/authz/pdp/transport.ex`, replace the `with` chain in `prepare/2` with a version that validates the common fields first, then requires `binding.parent_id` only when the action's capability is `:resource_control`:

```elixir
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
# binding; the binding must be present. An identity-proof action (feedback)
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
```

- [ ] **Step 3: Run the transport runner and watch it pass**

Run: `elixir /tmp/fb_prepare_runner.exs`
Expected: **PASS feedback-no-binding-ok** and **PASS dpp-still-requires-binding**.

- [ ] **Step 4: Add the `:proven_identity` branch to `load_facts/1`**

In `src/zenflows/authz/pdp.ex`, at the top of `load_facts/1`'s body (before the existing `with`), short-circuit identity-proof actions so no `ResourceControl` lookup is attempted:

```elixir
def load_facts(request) do
	proven? = request["principal_proven"] == true

	if capability(request["action"]) == :proven_identity do
		subject =
			case resolve_principal(get_in(request, ["principal", "pk"])) do
				%Person{id: id} -> id
				_ -> nil
			end

		%{"principal_proven" => proven?, "subject" => subject}
	else
		pk = get_in(request, ["principal", "pk"])
		parent_id = get_in(request, ["binding", "parent_id"])

		with %Person{id: person_id} <- resolve_principal(pk),
				{:ok, control} <- ResourceControl.Domain.one(Repo, parent_id) do
			# ... existing body unchanged ...
		else
			# ... existing else clauses unchanged ...
		end
	end
rescue
	e ->
		Logger.error("pdp load_facts crashed: #{inspect(e)}")
		%{"error" => "fact_load_failed"}
end
```

> **Integration-tier:** `load_facts/1` calls `Person.Domain.one/1` and so is exercised only against a live database (same posture as the DPP slice, whose `load_facts` is integration-tested, not unit-tested). Verify this step by code-read: the `:proven_identity` branch resolves the principal, returns `subject`, and performs no `ResourceControl` call. The policy it feeds is already proven by Task 1's decide vectors.

- [ ] **Step 5: Confirm Task 1 vectors still pass (no regression)**

Run: `elixir /tmp/fb_decide_runner.exs`
Expected: **ALL 3 GREEN** (unchanged — `decide/2` was not touched).

- [ ] **Step 6: Commit**

```bash
git add src/zenflows/authz/pdp.ex src/zenflows/authz/pdp/transport.ex
git commit -m "feat(authz): resolve feedback subject in load_facts; relax transport binding for identity actions

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Feedback — pure `internal/authz` request/response/interpret

**Repo/branch:** `interfacer-feedback-service`, `feat/authz-pep` (cut from `main`).

**Files:**
- Create: `internal/authz/authz.go`
- Test: `internal/authz/authz_test.go`

**Interfaces:**
- Produces: `authz.Proof{Signature, PayloadB64}`; `authz.Request`; `authz.Response{Decision, ReasonCode, Subject, …}`; `authz.Outcome{Allow, Status, ReasonCode, Subject}`; `authz.BuildRequest(requestID, action string, pk string, proof Proof) Request`; `authz.Interpret(resp Response, transportErr error) Outcome`.

- [ ] **Step 1: Write the failing test**

Create `internal/authz/authz_test.go`:

```go
package authz

import (
	"errors"
	"testing"
)

func TestBuildRequestFixesActionAndCarriesProof(t *testing.T) {
	req := BuildRequest("rid-1", "feedback.review.create", "pkAlice",
		Proof{Signature: "SIG", PayloadB64: "e30="})
	if req.Action != "feedback.review.create" {
		t.Fatalf("action: got %q", req.Action)
	}
	if req.Principal.Pk != "pkAlice" {
		t.Fatalf("pk: got %q", req.Principal.Pk)
	}
	if req.Proof.Signature != "SIG" || req.Proof.PayloadB64 != "e30=" {
		t.Fatalf("proof not carried: %+v", req.Proof)
	}
	if req.RequestID != "rid-1" {
		t.Fatalf("request id: got %q", req.RequestID)
	}
}

func TestInterpretAllowWithSubjectProceeds(t *testing.T) {
	out := Interpret(Response{Decision: "allow", ReasonCode: "ok", Subject: "01PERSONALICE"}, nil)
	if !out.Allow || out.Status != 200 || out.Subject != "01PERSONALICE" {
		t.Fatalf("allow+subject must proceed with subject: %+v", out)
	}
}

func TestInterpretAllowWithEmptySubjectFailsClosed(t *testing.T) {
	out := Interpret(Response{Decision: "allow", ReasonCode: "ok", Subject: ""}, nil)
	if out.Allow || out.Status != 403 {
		t.Fatalf("an allow without a proven subject must fail closed: %+v", out)
	}
}

func TestInterpretDenyIs403(t *testing.T) {
	out := Interpret(Response{Decision: "deny", ReasonCode: "principal_not_resolved"}, nil)
	if out.Allow || out.Status != 403 || out.ReasonCode != "principal_not_resolved" {
		t.Fatalf("deny: %+v", out)
	}
}

func TestInterpretTransportErrorFailsClosed(t *testing.T) {
	out := Interpret(Response{}, errors.New("connection refused"))
	if out.Allow || out.Status != 403 || out.ReasonCode != "pdp_unreachable" {
		t.Fatalf("transport error must fail closed: %+v", out)
	}
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `go test ./internal/authz/`
Expected: FAIL — `undefined: BuildRequest`, `Proof`, `Response`, `Interpret`, `Outcome`.

- [ ] **Step 3: Write `authz.go`**

Create `internal/authz/authz.go`:

```go
// Package authz is the feedback service's enforcement-point client of the
// cross-service Policy Decision Point. BuildRequest and Interpret are pure so
// the request shape and the fail-closed mapping are unit-testable without a
// live PDP. The action is fixed by the route; the PDP returns the proven
// subject (Person.id) the service writes under — never the self-asserted
// x-user-id header.
package authz

// Proof carries the exact signed bytes (base64) and their signature, so the
// PDP re-verifies the user's own signature (contract §4.3 property 2).
type Proof struct {
	Signature  string `json:"signature"`
	PayloadB64 string `json:"payload_b64"`
}

// Request is the contract request for an identity-proof (feedback) action: no
// binding, since feedback has no resource parent.
type Request struct {
	RequestID string `json:"request_id"`
	Action    string `json:"action"`
	Principal struct {
		Pk string `json:"pk"`
	} `json:"principal"`
	Proof Proof `json:"proof"`
}

// Response is the contract response. Subject is the proven Person.id, present
// only on an allow that resolved the key.
type Response struct {
	Decision      string         `json:"decision"`
	ReasonCode    string         `json:"reason_code"`
	Subject       string         `json:"subject"`
	Obligations   map[string]any `json:"obligations"`
	RequestID     string         `json:"request_id"`
	PolicyVersion string         `json:"policy_version"`
}

// Outcome is what the middleware enforces.
type Outcome struct {
	Allow      bool
	Status     int
	ReasonCode string
	Subject    string
}

// BuildRequest assembles the wire request. action is supplied by the route.
func BuildRequest(requestID, action, pk string, proof Proof) Request {
	var r Request
	r.RequestID = requestID
	r.Action = action
	r.Principal.Pk = pk
	r.Proof = proof
	return r
}

// Interpret maps a PDP response (or transport error) to an enforced outcome.
// Fail closed: only an "allow" that carries a proven subject proceeds.
func Interpret(resp Response, transportErr error) Outcome {
	if transportErr != nil {
		return Outcome{Allow: false, Status: 403, ReasonCode: "pdp_unreachable"}
	}
	if resp.Decision == "allow" {
		if resp.Subject == "" {
			return Outcome{Allow: false, Status: 403, ReasonCode: "no_subject"}
		}
		return Outcome{Allow: true, Status: 200, ReasonCode: resp.ReasonCode, Subject: resp.Subject}
	}
	reason := resp.ReasonCode
	if reason == "" {
		reason = "denied"
	}
	return Outcome{Allow: false, Status: 403, ReasonCode: reason}
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `go test ./internal/authz/`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add internal/authz/authz.go internal/authz/authz_test.go
git commit -m "feat(authz): pure PDP request-builder and fail-closed interpreter (subject-proving)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Feedback — PDP HTTP client

**Repo/branch:** `interfacer-feedback-service`, `feat/authz-pep`.

**Files:**
- Create: `internal/authz/client.go`
- Test: `internal/authz/client_test.go`

**Interfaces:**
- Consumes: `authz.Request`, `authz.Response` (Task 3).
- Produces: `authz.Client{BaseURL, HTTP}`; `authz.NewClientFromEnv() *Client`; `(*Client).Decide(ctx, Request) (Response, error)`.

- [ ] **Step 1: Write the failing test**

Create `internal/authz/client_test.go`:

```go
package authz

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDecodePDPResponse(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/authz/decide" {
			t.Errorf("path: got %q", r.URL.Path)
		}
		_ = json.NewEncoder(w).Encode(Response{Decision: "allow", ReasonCode: "ok", Subject: "01PERSONALICE"})
	}))
	defer srv.Close()

	c := &Client{BaseURL: srv.URL, HTTP: srv.Client()}
	resp, err := c.Decide(context.Background(), BuildRequest("r", "feedback.review.create", "pk", Proof{}))
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if resp.Decision != "allow" || resp.Subject != "01PERSONALICE" {
		t.Fatalf("decoded: %+v", resp)
	}
}

func TestDecideErrorsOnEmptyBaseURL(t *testing.T) {
	c := &Client{BaseURL: "", HTTP: http.DefaultClient}
	if _, err := c.Decide(context.Background(), Request{}); err == nil {
		t.Fatal("empty base URL must error")
	}
}

func TestDecideErrorsOnNon2xx(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	c := &Client{BaseURL: srv.URL, HTTP: srv.Client()}
	if _, err := c.Decide(context.Background(), Request{}); err == nil {
		t.Fatal("non-2xx must error")
	}
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `go test ./internal/authz/`
Expected: FAIL — `undefined: Client`, `NewClientFromEnv`, `Decide`.

- [ ] **Step 3: Write `client.go`**

Create `internal/authz/client.go` (ported from the DPP client, same contract):

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
// response. A missing base URL, transport failure, non-2xx status, or
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

- [ ] **Step 4: Run it and watch it pass**

Run: `go test ./internal/authz/`
Expected: PASS (8 tests total in the package).

- [ ] **Step 5: Commit**

```bash
git add internal/authz/client.go internal/authz/client_test.go
git commit -m "feat(authz): PDP HTTP client, fail-closed on unreachable/non-2xx

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Feedback — `AuthzMiddleware` (self-contained)

**Repo/branch:** `interfacer-feedback-service`, `feat/authz-pep`.

**Files:**
- Create: `internal/auth/authz_middleware.go`
- Test: `internal/auth/authz_middleware_test.go`

**Interfaces:**
- Consumes: `authz.Client`, `authz.BuildRequest`, `authz.Interpret`, `authz.Proof` (Tasks 3–4).
- Produces: `auth.AuthzMiddleware(client *authz.Client, action string) gin.HandlerFunc` — reads `did-pk`/`did-sign` + the raw body, calls the PDP for `action`, on `!Allow` writes 403+abort, on allow sets `c.Set("user_ulid", subject)`; `auth.NewRequestID() string`.

- [ ] **Step 1: Write the failing test**

Create `internal/auth/authz_middleware_test.go`:

```go
package auth

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/interfacerproject/interfacer-feedback-service/internal/authz"
)

func ctxFor(method, body string) (*gin.Context, *httptest.ResponseRecorder) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	req := httptest.NewRequest(method, "/api/v1/projects/P1/reviews", strings.NewReader(body))
	req.Header.Set("did-pk", "pkAlice")
	req.Header.Set("did-sign", "SIG")
	req.Header.Set("x-user-id", "VICTIM") // a lie the middleware must ignore
	c.Request = req
	return c, w
}

func stubPDP(t *testing.T, resp authz.Response) *authz.Client {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(resp)
	}))
	t.Cleanup(srv.Close)
	return &authz.Client{BaseURL: srv.URL, HTTP: srv.Client()}
}

func TestAuthzProvenSubjectOverridesLyingHeader(t *testing.T) {
	c, w := ctxFor(http.MethodPost, `{"rating":5}`)
	mw := AuthzMiddleware(stubPDP(t, authz.Response{Decision: "allow", ReasonCode: "ok", Subject: "ALICE"}), "feedback.review.create")
	mw(c)
	if c.IsAborted() || w.Code == http.StatusForbidden {
		t.Fatalf("allow should proceed: aborted=%v code=%d", c.IsAborted(), w.Code)
	}
	if got := c.GetString("user_ulid"); got != "ALICE" {
		t.Fatalf("user_ulid must be the proven subject, not the header: got %q", got)
	}
}

func TestAuthzBodyRestoredForHandler(t *testing.T) {
	c, _ := ctxFor(http.MethodPost, `{"rating":5}`)
	mw := AuthzMiddleware(stubPDP(t, authz.Response{Decision: "allow", Subject: "ALICE"}), "feedback.review.create")
	mw(c)
	b, _ := io.ReadAll(c.Request.Body)
	if string(b) != `{"rating":5}` {
		t.Fatalf("body must be restored for the handler: got %q", string(b))
	}
}

func TestAuthzDenyIs403(t *testing.T) {
	c, w := ctxFor(http.MethodDelete, `{}`)
	mw := AuthzMiddleware(stubPDP(t, authz.Response{Decision: "deny", ReasonCode: "principal_not_resolved"}), "feedback.review.delete")
	mw(c)
	if !c.IsAborted() || w.Code != http.StatusForbidden {
		t.Fatalf("deny must be 403+abort: aborted=%v code=%d", c.IsAborted(), w.Code)
	}
}

func TestAuthzUnreachableFailsClosed(t *testing.T) {
	c, w := ctxFor(http.MethodDelete, `{}`)
	mw := AuthzMiddleware(&authz.Client{BaseURL: "", HTTP: http.DefaultClient}, "feedback.review.delete")
	mw(c)
	if !c.IsAborted() || w.Code != http.StatusForbidden {
		t.Fatalf("unreachable PDP must fail closed: aborted=%v code=%d", c.IsAborted(), w.Code)
	}
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `go test ./internal/auth/`
Expected: FAIL — `undefined: AuthzMiddleware`.

- [ ] **Step 3: Write `authz_middleware.go`**

Create `internal/auth/authz_middleware.go`:

```go
package auth

import (
	"bytes"
	"context"
	"crypto/rand"
	b64 "encoding/base64"
	"encoding/hex"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/interfacerproject/interfacer-feedback-service/internal/authz"
)

// NewRequestID returns an opaque id for correlating a decision in logs.
func NewRequestID() string {
	var b [8]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}

// AuthzMiddleware authorizes a write by asking the PDP to prove the acting
// subject from the request's own signature. It re-reads the raw body (the
// exact bytes the client signed — real JSON on create, "{}" on delete),
// restores it for the handler, and sends did-pk + did-sign + base64(body) as
// the proof. On allow it sets user_ulid to the PDP-returned proven subject,
// ignoring the self-asserted x-user-id header. On deny or any transport error
// it writes 403 and aborts (fail closed). Identity is proven at the PDP; the
// authn middleware's local signature check remains the 401 floor.
func AuthzMiddleware(client *authz.Client, action string) gin.HandlerFunc {
	return func(c *gin.Context) {
		body, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "unreadable body"})
			return
		}
		c.Request.Body = io.NopCloser(bytes.NewReader(body))

		proof := authz.Proof{
			Signature:  c.Request.Header.Get("did-sign"),
			PayloadB64: b64.StdEncoding.EncodeToString(body),
		}
		req := authz.BuildRequest(NewRequestID(), action, c.Request.Header.Get("did-pk"), proof)

		ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
		defer cancel()

		resp, derr := client.Decide(ctx, req)
		out := authz.Interpret(resp, derr)
		if !out.Allow {
			log.Printf("feedback authz denied: reason=%s action=%s route=%s",
				out.ReasonCode, action, c.FullPath())
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error":  "not authorized for this operation",
				"reason": out.ReasonCode,
			})
			return
		}
		c.Set("user_ulid", out.Subject)
		c.Next()
	}
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `go test ./internal/auth/`
Expected: PASS (4 tests). Note `TestAuthzProvenSubjectOverridesLyingHeader` proves `user_ulid == "ALICE"` though the header said `VICTIM`.

- [ ] **Step 5: Commit**

```bash
git add internal/auth/authz_middleware.go internal/auth/authz_middleware_test.go
git commit -m "feat(authz): AuthzMiddleware proves subject via PDP, overrides x-user-id

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Feedback — wire the middleware and stop trusting `x-user-id`

**Repo/branch:** `interfacer-feedback-service`, `feat/authz-pep`.

**Files:**
- Modify: `internal/auth/middleware.go` (remove the `x-user-id` guard + `c.Set("user_ulid", …)`)
- Modify: `cmd/main/main.go` (construct the authz client; register `AuthzMiddleware` after `authMW` on the four write routes)
- Modify: `.env.example` (document `ZENFLOWS_PDP_URL`)

**Interfaces:**
- Consumes: `auth.AuthzMiddleware`, `authz.NewClientFromEnv` (Tasks 4–5).

- [ ] **Step 1: Remove the `x-user-id` trust from `AuthMiddleware`**

In `internal/auth/middleware.go`, delete the block that rejects a missing `x-user-id`:

```go
		if userULID == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error":   "Authentication failed",
				"details": "Missing x-user-id header",
			})
			return
		}
```

and delete the trailing `c.Set("user_ulid", userULID)` and the now-unused `userULID := c.Request.Header.Get("x-user-id")`. The signature checks (missing `did-sign`/`did-pk` → 401, `VerifyDid`, `IsAuth`) stay exactly as they are — the 401 authn floor is unchanged. `AuthzMiddleware` now sets `user_ulid` from the proven subject.

- [ ] **Step 2: Build to verify authn still compiles and the floor is intact**

Run: `go build ./...`
Expected: builds clean. Code-read check: `middleware.go` still returns 401 when `signature == "" || publicKey == ""` and still calls `IsAuth()`.

- [ ] **Step 3: Register `AuthzMiddleware` on the four write routes**

In `cmd/main/main.go`, after `authMW := auth.AuthMiddleware()`:

```go
	authMW := auth.AuthMiddleware()
	pdp := authz.NewClientFromEnv()
	az := func(action string) gin.HandlerFunc { return auth.AuthzMiddleware(pdp, action) }
```

Add `"github.com/interfacerproject/interfacer-feedback-service/internal/authz"` to the imports, and insert `az("<action>")` between `authMW` and each write handler:

```go
	router.POST("/api/v1/projects/:project_ulid/reviews", authMW, az("feedback.review.create"), handler.CreateReview(db, publisher))
	router.DELETE("/api/v1/reviews/:review_id", authMW, az("feedback.review.delete"), handler.DeleteReview(db, publisher))
	router.POST("/api/v1/projects/:project_ulid/comments", authMW, az("feedback.comment.create"), handler.CreateComment(db))
	router.DELETE("/api/v1/comments/:comment_id", authMW, az("feedback.comment.delete"), handler.DeleteComment(db))
```

(GET routes are untouched — reads stay public.)

- [ ] **Step 4: Document the env var**

Append to `.env.example`:

```
# URL of the internal Zenflows PDP that proves the acting user's identity for
# write authorization. If unset or unreachable, all writes fail closed (403).
ZENFLOWS_PDP_URL=http://localhost:8000
```

- [ ] **Step 5: Build + full suite**

Run: `go build ./... && go vet ./... && go test ./...`
Expected: builds clean; vet clean; all packages pass (the new `authz` and `auth` tests plus the existing `handler`/`database` suites). `go.mod` unchanged (no new dependencies — `AuthzMiddleware` uses only stdlib + gin + the new internal package).

- [ ] **Step 6: Commit**

```bash
git add internal/auth/middleware.go cmd/main/main.go .env.example
git commit -m "feat(authz): wire AuthzMiddleware on feedback writes; drop x-user-id trust

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the final reviewer

- **Byte correspondence:** `AuthzMiddleware` sends `payload_b64 = base64(rawBody)`; the client signs the raw body (real JSON on create, `"{}"` on delete). Confirm the PDP's `verify_graphql` re-verification (identical `{gql, eddsa_signature, eddsa_public_key}` shape) matches these bytes — the property the whole slice rests on.
- **Middleware order** (`authMW` before `az(...)`) and that `az` is on exactly the four write routes are integration-tier (verified by build + code-read); the unit tests exercise `AuthzMiddleware` in isolation.
- **`load_facts/1` `:proven_identity` branch** is integration-tier (needs a live DB for `Person.Domain.one`); its policy is covered by Task 1's pure decide vectors.
