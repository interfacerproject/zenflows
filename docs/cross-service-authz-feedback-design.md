# Cross-service authorization: feedback PEP (subject-proving)

Workstream: interfacerproject/zenflows#74 (non-closing reference).
Status: **design, approved 2026-10-15** (owner). Implemented on feature
branches / draft PRs only; no change to `main`/`master` of gui or zenflows.

This is the **second** service wired to the cross-service PDP, after the DPP
slice (`cross-service-authz-transport-design.md`). It reuses that transport
(`POST /authz/decide`, the `proof` block, the Go `internal/authz` pattern)
unchanged in shape and extends it in one way: the PDP now returns the
**proven subject** it resolves from the signing key. It does not re-open any
ratified contract or decision.

## 1. What exists, and the gap this closes

`interfacer-feedback-service` (Go/Gin, SQLite) mirrors the DPP auth model:
its `AuthMiddleware` verifies an EdDSA/DID signature over the request body
through the same embedded `verify_graphql.zen`. But it then takes the acting
user's identity from a **self-asserted header**:

```go
// internal/auth/middleware.go — after IsAuth() passes:
c.Set("user_ulid", c.Request.Header.Get("x-user-id"))
```

The signature proves only that *the holder of `did-pk` signed these bytes*.
It is never bound to `x-user-id`. The Epic assumes "`x-user-id` is set by the
proxy/gateway after auth" — but `interfacer-proxy` is a plain reverse proxy
(`req.Header = r.Header`, `// TODO: implement an authentication mechanism`):
it forwards every client header verbatim and binds nothing. So the premise is
false in this codebase, and the gap is live:

> A caller signs the body with *their own* valid key (passes `IsAuth`) and
> sends `x-user-id: <victim>`. The feedback service then writes reviews and
> comments **as the victim**, and `DeleteReview(db, id, user_ulid)` /
> `SoftDeleteComment(db, id, user_ulid)` delete **the victim's** content —
> because the per-row ownership SQL keys on the header the attacker controls.

This is exactly what contract §4.3 property 2 forbids (a service — here, via a
caller it trusts — asserting an arbitrary subject without proof; ratified as
`deny.service_asserts_subject_without_proof`).

Feedback's *resource policy* is otherwise thin and already correct **once the
subject is real** (Epic §Authorization): any authenticated user may create or
update their own review (`UNIQUE(project_ulid, user_ulid)` = one per project);
comment deletion is author-only. So this slice is not about inventing policy.
**It replaces the self-asserted subject with a proven one.**

Identity is resolvable because `x-user-id` *is* the Zenflows `Person.id`: the
client sets it from `createPerson.agent.id` (signup) and
`verifyUser(email, eddsaPublicKey) → person.id` (login), and signs with that
same Person's `eddsa_public_key`. The Zenflows PDP therefore maps the proof's
`pk` straight to the `Person.id` feedback writes under — it already does this
in `Pdp.load_facts/1` via `resolve_principal/1`.

## 2. Trust model (decided)

**The PDP re-verifies the user's signature and returns the proven subject
(`Person.id`). Feedback writes under that id and treats `x-user-id` as
non-authoritative.** (Owner's decision: "PDP returns proven id".) A lying,
stale, or absent `x-user-id` cannot impersonate anyone — the header stops
being a security input. Ownership rules stay in feedback (decision: "stay in
feedback SQL"): the PDP proves *who*, feedback's existing `WHERE author = …`
and `UNIQUE(project_ulid, user_ulid)` enforce *what they may touch*, now on a
proven id. No service credential this slice; the PDP endpoint is internal, as
in the DPP slice.

This keeps the service boundary clean: **Zenflows owns identity** (it alone
holds the `pk → Person` mapping); **feedback owns its rows.**

## 3. PDP change (Zenflows, Elixir)

The transport (`POST /authz/decide`, `Pdp.Transport`) and the `proof`
re-verification are unchanged. Two additive changes to the pure core
(`Zenflows.Authz.Pdp`), both non-breaking for the DPP actions:

### 3.1 A feedback action family

New entries in the `@actions` registry, carrying a new capability that means
"identity proof only — no resource control":

```
feedback.review.create   -> :proven_identity
feedback.review.delete   -> :proven_identity
feedback.comment.create  -> :proven_identity
feedback.comment.delete  -> :proven_identity
```

An action absent from `@actions` is still refused (`unknown_action`), so the
default-deny posture is unchanged.

### 3.2 The proven subject in facts and response

- `load_facts/1` gains an early branch for `:proven_identity` actions: resolve
  the principal with the existing `resolve_principal/1` and return
  `%{"principal_proven" => proven?, "subject" => person_id}` **without** a
  `ResourceControl` lookup (there is no bound parent). An unresolved key →
  `subject: nil`.
- `decide/2` gains a branch for the `:proven_identity` capability:
  `principal_proven == true` **and** a non-nil `subject` → `allow` carrying the
  subject; otherwise `deny("principal_not_resolved", …)`. (The existing
  `principal_proven != true → unproven_subject` guard still runs first.)
- `allow/2` (and `tag/2`) include a `"subject"` key **when present**. DPP
  responses carry no subject and are unaffected; the DPP Go client already
  ignores unknown response fields.

No binding/`parent_id` is required for feedback requests; the transport's
existing validation must therefore treat `binding.parent_id` as **optional**
when the action is in the feedback family (see §6 testing — the current
transport requires it; this slice relaxes it for `:proven_identity` actions).

## 4. Feedback PEP → PDP (Go)

### 4.1 New package `internal/authz`

The DPP `internal/authz` pattern, ported, with the subject added:

- **Pure, table-testable:**
  - `BuildRequest(requestID, action string, p Proof, pk string) Request` — the
    request carries `request_id`, `action` (fixed by the route), `principal.pk`,
    and the `proof`. No `binding` (feedback has no resource parent).
  - `Interpret(resp Response, transportErr error) Outcome` where
    `Outcome{Allow bool; Status int; ReasonCode, Subject string}`. Fail closed:
    `allow` **with a non-empty `subject`** → proceed; `allow` with an empty
    subject, any `deny`, or any transport error → **deny/403**. An allow
    without a proven subject is not a grant.
- **Thin I/O:** `Client{BaseURL, HTTP}`, `NewClientFromEnv()` (reads
  `ZENFLOWS_PDP_URL`, a timeout, resolved **lazily** at first use so it sees
  the `.env` loaded in `main()`), `Decide(ctx, Request) (Response, error)` —
  POST JSON, error on empty base URL / non-2xx / decode failure.

### 4.2 Middleware placement

Feedback has a single choke point the DPP did not: `AuthMiddleware` already
runs on every write route. Enforcement is therefore a **second middleware**,
`AuthzMiddleware`, registered after `AuthMiddleware` on the same routes — not
per-handler. This mirrors the DPP authn/authz split (authenticate, then
authorize) and leaves the four handlers **untouched**: they keep reading
`c.GetString("user_ulid")`.

`AuthMiddleware` is adjusted to stash what the authz step needs rather than
trust the header:

1. `AuthMiddleware` (authn floor, unchanged outcome): verify the signature
   locally; on failure `401`. On success it stashes the raw body's
   `payload_b64` (the `Gql` it already computes) and the `did-pk` / `did-sign`
   header values in the context. It **no longer** sets `user_ulid` from
   `x-user-id`, and its current "missing `x-user-id` → 401" guard is
   **removed** — the header is no longer required or trusted, so a correct
   client that omits it must not be rejected.
2. `AuthzMiddleware` (new): build the proof from the stashed values, map
   `method + c.FullPath()` to the route action, call the PDP, `Interpret`. On
   `!Allow` → `403` + abort. On allow → `c.Set("user_ulid", out.Subject)` — the
   **proven** id — and continue.

| Route                                            | Method | Action                   |
|--------------------------------------------------|--------|--------------------------|
| `/api/v1/projects/:project_ulid/reviews`         | POST   | `feedback.review.create` |
| `/api/v1/reviews/:review_id`                     | DELETE | `feedback.review.delete` |
| `/api/v1/projects/:project_ulid/comments`        | POST   | `feedback.comment.create`|
| `/api/v1/comments/:comment_id`                   | DELETE | `feedback.comment.delete`|

The action is fixed by the route, never read from the client (contract §3).

### 4.3 Signed-byte correspondence

The feedback client signs the **raw request body** in all four cases — real
JSON for creates, the literal `{}` for deletes (`deleteReview`/`deleteComment`
pass `{}` as the body, so `signDidRequest` signs `"{}"`). The authn middleware
already computes `Gql = base64(rawBody)` for its own verification, so
`payload_b64 = base64(rawBody)` is correct uniformly, with **no per-route
signing-material special-casing**. The PDP re-runs the identical
`{gql, eddsa_signature, eddsa_public_key}` verification, so PEP and PDP agree
on what was signed by construction.

### 4.4 Enforcement (decided: enforce now)

`allow` + proven subject → proceed; `deny`, unresolved key, PDP error, or
unreachable → **`403`** and abort. Authentication failure stays `401`
(unchanged `AuthMiddleware`). New env `ZENFLOWS_PDP_URL`; absent or unreachable
fails closed to `403`.

## 5. Honest limitations

- **Replay:** inherited from the transport — no nonce/timestamp signed
  envelope yet. A captured `(payload, signature)` for a `pk` is replayable to
  the internal PDP, and would prove that user's identity. For creates this
  could re-post a user's own already-signed comment/review; the endpoint is
  internal. Real and named; deferred with the DPP slice's envelope follow-up.
- **No service credential** (chosen): any party reaching the internal PDP may
  ask; identity is still always re-proven, so no subject can be forged.
- **Fail-closed reach:** "enforce now" + PDP down ⇒ all four writes `403`.
- **`x-user-id` left on the wire:** the GUI/SDK still send it; feedback ignores
  it for security. Removing it client-side is a later, non-security cleanup
  (the header becomes dead weight, not a vulnerability).
- **Integration-only properties:** that `AuthzMiddleware` is wired after
  `AuthMiddleware` on exactly the write routes, and that the real `pk→Person`
  resolution matches a live database, are verified by build + code read + the
  Zenflows integration path, not by the Go unit tests.

## 6. Scope boundaries (YAGNI)

**In:** the four feedback write routes; the PDP feedback action family + proven
`subject`; the Go `internal/authz` package and `AuthzMiddleware`;
`ZENFLOWS_PDP_URL`; enforce-now.

**Out:** GUI/SDK/proxy changes (none needed — the client already signs the body
and sends `did-pk`); `GET /reviews/mine` and other reads (public per the Epic;
no confidentiality to protect, reviews are world-readable); wallet and inbox
(later slices); the replay envelope and a per-service PDP credential (still
deferred); extracting a shared cross-repo Go authz module (two consumers in two
repos do not justify module infrastructure yet — port the proven pattern and
note the extraction path).

## 7. Testing

- **Elixir (PDP):** keep the existing `Pdp` vectors green. Add contract
  vectors for the feedback family: proven key → `allow` with `subject`;
  unproven (`principal_proven=false`) → `unproven_subject`; proven but
  unresolved key → `principal_not_resolved`. Add `Pdp.Transport` unit tests
  that a feedback-action request **without** `binding.parent_id` is accepted
  (not `400`) and that `subject` is surfaced, using the injected `verify_fun`
  and `resolve_fun` stubs (no zenroom, no Postgres in unit tests).
- **Go (feedback):** unit tests for `BuildRequest` (action fixed by route; no
  binding; proof populated) and `Interpret` (allow+subject → proceed;
  allow+empty-subject → 403; deny → 403; transport error → 403). A
  `Client.Decide` test against an `httptest` server. `AuthzMiddleware` tests
  with an `httptest` PDP stub: a **proven subject overrides a lying
  `x-user-id`** (the central property), deny → 403 + abort, unreachable → 403,
  `ZENFLOWS_PDP_URL` resolved at call time.

## 8. Files touched

- **zenflows** (branch `feat/authz-feedback-pdp`, stacked on `feat/authz-pdp`):
  `src/zenflows/authz/pdp.ex` (feedback actions, `subject` in facts/response),
  `src/zenflows/authz/pdp/transport.ex` (optional binding for the feedback
  family, surface `subject`), their tests.
- **interfacer-feedback-service** (branch `feat/authz-pep`, off `main`): new
  `internal/authz/` package (pure + client + tests); new
  `internal/auth/authz_middleware.go`; `internal/auth/middleware.go` adjusted
  to stash proof and stop trusting `x-user-id`; `AuthzMiddleware` registered on
  the four write routes in `cmd/main/main.go`; `ZENFLOWS_PDP_URL` in
  `.env.example`.
- **zenflows-authz-docs** (branch `docs/authz-feedback`): this file;
  `docs/cross-service-authz/contract.json` feedback vectors; the plan.
