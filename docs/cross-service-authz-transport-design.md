# Cross-service authorization: PDP transport + first wiring

Workstream: interfacerproject/zenflows#74 (non-closing reference).
Status: **design, approved 2026-10-15** (owner). Implemented on feature
branches / draft PRs only; no change to `main`/`master` of gui or zenflows.

This design follows the ratified contract (`cross-service-authz-contract.md`)
and decision (`cross-service-authz-decision.md`). It does not re-open any of
their decisions; it specifies how the already-built decision point
(`Zenflows.Authz.Pdp`) is exposed over the wire and how the DPP enforcement
point calls it for its four state-changing write handlers.

## 1. What exists, and the gap this closes

- **PEP (DPP, Go)** already produces a *verified principal* from an
  EdDSA/DID signature over the object-id (deletes) or body (updates)
  — the authentication floor, contract §2. It does **not** call anyone
  to authorize the action.
- **PDP (Zenflows, Elixir)** — `Zenflows.Authz.Pdp.decide/2` is pure and
  driven green by the shared vectors (`cross-service-authz/contract.json`,
  7/7); `load_facts/1` reads control facts from `ResourceControl`. But
  **nothing is exposed over the wire**, and `load_facts/1` takes
  `principal_proven` from an "already-verified field" that is currently
  always false — so, correctly, nothing is ever granted yet.
- **Zenflows already owns a user-signature verifier**:
  `Restroom.verify_graphql(body, sign, eddsa_public_key)`, used by the
  GraphQL `Sign` middleware. The DPP PEP verifies the *same* kind of
  signature through the *same* embedded `verify_graphql.zen`.

The gap: (1) expose the PDP, (2) carry the acting user's proof to it so
`principal_proven` is set honestly — contract §4.3 property 2 (a service
may not assert an arbitrary subject; ratified as the
`deny.service_asserts_subject_without_proof` vector) is the binding
constraint — and (3) make the DPP PEP call the PDP and enforce the result.

## 2. Trust model (decided)

The PDP **re-verifies the user's own signature itself** and trusts no
identity claim from the caller. No service credential this slice; the PDP
endpoint is internal (behind the path proxy, not routed publicly). This is
the owner's chosen option: it fully honors §4.3 property 2 because identity
is always re-proven from the user's signature, independent of which service
relays it.

## 3. PDP transport (Zenflows, Elixir)

### 3.1 Endpoint

A new internal Plug route on `Zenflows.Web.Router`:

```
POST /authz/decide
```

Machine-to-machine; deliberately **not** a GraphQL field — it is not part of
the public ValueFlows surface and should be lockable to the internal network
independently of the GraphQL API.

### 3.2 Request body

```json
{
  "request_id": "<opaque, logs only>",
  "action": "dpp.spec.update",
  "principal": { "pk": "<eddsa_public_key>" },
  "binding":   { "parent_id": "<EconomicResource id>" },
  "proof":     { "signature": "<eddsa_signature>",
                 "payload_b64": "<base64 of the exact signed bytes>" }
}
```

`payload_b64` is the raw bytes the PEP already verified (the request body for
updates, the object-id string for deletes), base64-encoded for JSON
transport. The PDP decodes it and runs the identical
`{gql: base64(payload), eddsa_signature, eddsa_public_key}` verification, so
PEP and PDP agree on what was signed by construction.

### 3.3 New module: `Zenflows.Authz.Pdp.Transport`

A thin boundary; the pure `Pdp` core is untouched.

1. Parse and validate the JSON. Missing/!string `action`, `principal.pk`,
   `binding.parent_id`, `proof.signature`, `proof.payload_b64`, or a
   `payload_b64` that is not valid base64 → **`400`** with a small error body.
2. Re-verify the user proof:
   `verify_fun.(Base.decode64!(payload_b64), signature, pk)` where
   `verify_fun` defaults to `&Restroom.verify_graphql/3` and is injectable
   for unit tests. `principal_proven = (result == :ok)`. The caller may *not*
   supply `principal_proven`; the transport sets it solely from this result.
   (Verification only proves the holder of `pk` signed those bytes; whether
   `pk` belongs to a registered `Person` and controls the parent is decided
   later by `load_facts/1`/`decide/2`.)
3. Put `principal_proven` into the request map and call
   `Pdp.decision(request)`.
4. Respond **`200`** with the contract response body (`decision`,
   `reason_code`, `permission_epoch`, `obligations`, `request_id`,
   `policy_version`) for every rendered decision — `allow` and `deny` alike
   are "the PDP answered". `decision/1` already rescues internal failures to
   a fail-closed `deny`, so a crash still yields a `200 deny`, never a grant.

Router placement: a dedicated `post "/authz/decide"` match before the
`forward "/api"` clauses. It reads the raw body via the existing
`read_body/2` assign rather than Absinthe, and does not pass through the
GraphQL `Sign` middleware.

## 4. DPP PEP → PDP (Go)

### 4.1 New package `internal/authz`

Mirrors the existing `internal/auth` split (pure policy + thin I/O):

- **Pure, table-/vector-testable:**
  - `BuildRequest(principal *auth.Principal, action, parentID string, proof Proof) Request`
    — assembles the wire request; `parentID` is passed in by the caller
    (derived from the stored object), never read from client payload.
  - `Interpret(resp Response, transportErr error) Outcome` — `allow` →
    proceed; `deny` *or* any transport error → **deny/403**. Fail closed.
- **Thin I/O:** `Client.Decide(ctx, Request) (Response, error)` — POST JSON to
  `ZENFLOWS_PDP_URL`, with a timeout; decode the contract response.

### 4.2 Handler wiring

Authorization is a step **after** the object is loaded (the PEP needs the
stored DPP to derive `parent_id`), so it is a new helper
`authorizeWrite(c, principal, action, parentID) bool` called after the
existing `authenticateWrite` and after the DPP is fetched — not inside
`authenticateWrite`.

| Handler            | Route action           | `parent_id` source        |
|--------------------|------------------------|---------------------------|
| `UpdateDPP`        | `dpp.spec.update`      | stored `dpp.ProductID`    |
| `UpdateDPPStatus`  | `dpp.status.update`    | stored `dpp.ProductID`    |
| `DeleteDPP`        | `dpp.delete`           | stored `dpp.ProductID`    |
| `DeleteAttachment` | `dpp.attachment.delete`| stored `dpp.ProductID`    |

The action is **fixed by the route**, never taken from the client
(contract §3). `parent_id` is the stored DPP's `ProductID`, treated as a
Zenflows `EconomicResource` id, loaded server-side (honors
`deny.parent_from_binding_not_payload`). The `proof` carries the `pk`,
the `did-sign` header value, and `payload_b64 = base64(signed bytes)` the
PEP already holds.

### 4.3 Enforcement (decided: enforce now)

On the feature branch, `allow` → proceed; `deny` or transport
error/unreachable → **`403`** and abort. Status split: authentication
failure stays `401` (existing `authenticateWrite`); authorization failure
is `403` (new). New env `ZENFLOWS_PDP_URL`; absent or unreachable fails
closed to `403`.

## 5. Honest limitations (also stated in the PRs)

- **Replay:** without the nonce/timestamp signed envelope (documented
  deferred follow-up, contract §2 shipping note), a captured
  `(payload, signature)` pair for a `pk` is replayable to the internal PDP.
  It can only ever authorize actions on resources that *that same user
  already controls*, and the endpoint is internal — but it is real and
  named here.
- **No service credential** (chosen): any party reaching the internal PDP
  may ask; identity is still always re-proven, so no subject can be forged.
- **Fail-closed reach:** "enforce now" + PDP down ⇒ all four writes `403`.
  Correct secure default; operationally the PDP must be reachable.
- **Coverage of grants:** a DPP whose `ProductID` is not a controlled
  `EconomicResource` will `deny`. Expected and honest for this slice.

## 6. Testing

- **Elixir:** keep the 7/7 pure `Pdp` vectors untouched. Add
  `Pdp.Transport` unit tests for request parsing/validation and the
  `principal_proven`-from-verification wiring, using an **injected
  `verify_fun` stub** (no zenroom in unit tests). The real crypto
  re-verification is the existing `Restroom.verify_graphql` path, covered by
  Zenflows' own tests; an integration note records that the end-to-end
  re-verify is exercised only with a live restroom.
- **Go:** unit tests for `BuildRequest` (correct action, `parent_id` from the
  object not the payload, proof fields populated) and `Interpret`
  (allow→proceed; deny/error→403), plus a `Client.Decide` test against an
  `httptest` server. No live Zenflows needed.

## 7. Scope boundaries (YAGNI)

**In:** the four write handlers already on `authenticateWrite`; the PDP
endpoint; the Go client; the honest enforce-now path.

**Out (same pattern, later, not this slice):** `CreateDPP` / file upload /
add-attachment; the wallet issuance slice; the nonce/timestamp signed
envelope; a per-service credential on the PDP endpoint; a dedicated
`transport.json` shared-vector layer (reuse `contract.json` plus Go table
tests for now).

## 8. Files touched

- **zenflows** (branch `feat/authz-pdp`): new
  `src/zenflows/authz/pdp/transport.ex`; a `post "/authz/decide"` match in
  `src/zenflows/web/router.ex`; `test/authz/pdp_transport.test.exs`.
  `pdp.ex` unchanged.
- **interfacer-dpp** (branch `feat/authn-dpp-writes`, or a stacked branch):
  new `internal/authz/` package (pure + client + tests); `authorizeWrite` in
  the handler package; the four write handlers gain the authorize step;
  `ZENFLOWS_PDP_URL` wired through config/`main`.
- **zenflows-authz-docs** (branch `docs/cross-service-authz`): this file.
