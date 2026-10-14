# Cross-service authorization: the contract

Companion to `cross-service-authz-decision.md` (ratified 2026-10-14). The
decision document fixes *where* decisions live (authority in Zenflows, a thin
PEP in each service) and *that* a contract exists; this document is the
contract itself — the fixed request/response shape a PEP sends and the PDP
answers, the non-negotiable properties, and the authentication floor the PEP
enforces before it ever calls the PDP.

It is written to be **implementation-independent**: the same contract is
realized by a Go library (DPP, wallet, inbox, feedback) and a small Elixir
counterpart on the Zenflows side. Conformance is pinned by the shared test
vectors in `docs/cross-service-authz/` (§6), which both
implementations consume.

No code is changed by this document.

## 1. Vocabulary

- **PEP** — Policy Enforcement Point. Lives in each service. Verifies the
  caller's signature, builds a *verified principal*, asks the PDP for a
  decision, and applies allow/deny plus obligations. Never decides on its own.
- **PDP** — Policy Decision Point. Lives in Zenflows, which owns the facts a
  decision depends on (controllers, object control, memberships, epochs). It
  answers a decision; it does not run the operation.
- **Verified principal** — the subject proven by a signature for *this*
  request. Never a header value. This is the whole point: today DPP writes
  `createdBy` from `x-user-id`, and feedback trusts `x-user-id` as the
  principal. Under this contract `x-user-id` is at most a *logged hint*, never
  trusted.
- **Action** — a registered string fixed by the handler (§3). The client
  cannot choose it.
- **Binding** — the parent/resource a write hangs off, loaded by the service
  from its own validated record, never from the request payload (§4.2).

## 2. The authentication floor (beneath the contract)

Before any PDP call, every **state-changing** request MUST carry a valid DID
signature. This is what today's DPP `create`/`upload` do and the four write
handlers (`UpdateDPP`, `UpdateDPPStatus`, `DeleteDPP`, `DeleteAttachment`) do
*not* — the first-slice P0.

The signature is EdDSA-over-Zenroom, verified with `verify_graphql.zen`, over
a **signed payload** that this contract now defines canonically, because the
services disagree today (some sign the JSON body; a body-less `DELETE` signs
nothing meaningful):

> **Signed payload** = the UTF-8 bytes of a JSON object with, at minimum:
> `action` (the registered action string, §3), `object` (`{type,id}`),
> `nonce` (client random, ≥128 bit), `timestamp` (RFC3339), and, for a write
> that carries data, `body` (the operation's domain payload).
>
> For requests that already have a JSON body today (e.g. `PUT /dpp/:id`), the
> body IS `body` inside this envelope; the envelope adds `action`/`object`/
> `nonce`/`timestamp` around it. For body-less requests (`DELETE`), there is
> no `body`; the envelope alone is signed.

The PEP, having verified the signature, MUST:

1. **Reject a missing or invalid signature — fail closed.** No fallback to the
   old unauthenticated path. (P0 for DPP: this alone closes "no authn at all".)
2. **Reject if the DID does not resolve** (`VerifyDid`).
3. **Bind the operation to the path.** The signed `object.id` MUST equal the
   id in the route (`/dpp/:id`). A signature over one object may not drive a
   write to another. This gives a body-less `DELETE` a signature that means
   *this* delete, not any delete.
4. **Reject a stale or replayed request** — `timestamp` within a short TTL and
   `nonce` unseen (review F06). *Shipping note:* the TTL/nonce check is a fast
   follow; the P0 DPP slice ships 1–3 and logs the fields, so the signed-payload
   shape is correct from day one and replay defense is turned on without a
   client change.

The verified principal produced here (`{did, pk}`) is the only subject the
PDP call may carry for the user.

## 3. Actions are fixed by the handler

Each state-changing handler maps to exactly one registered action. The client
never names the action; it is a property of the route reached.

| Service · route | Action |
| --- | --- |
| `POST /dpp` | `dpp.create` |
| `PUT /dpp/:id` | `dpp.spec.update` |
| `PUT /dpp/:id/status` | `dpp.status.update` |
| `DELETE /dpp/:id` | `dpp.delete` |
| `POST /dpp/:id/attachments` | `dpp.attachment.add` |
| `DELETE /dpp/:id/attachments/:a` | `dpp.attachment.delete` |
| `POST /upload` | `dpp.file.upload` |
| `POST /token` (wallet) | `wallet.points.issue` |

A caller holding a valid signature for a low-privilege action (say a read)
cannot present it to a high-privilege handler: the handler fixes the action,
so the PDP evaluates the privileged action regardless of what the client hoped
to invoke.

## 4. The PDP request/response

### 4.1 Request (PEP → PDP)

```
{
  "request_id":   "<ulid>",
  "principal":    { "did": "...", "pk": "<eddsa_public_key>" },
  "delegation":   null,            // or an operation-scoped assertion (§4.3)
  "service":      { "id": "dpp", "credential": "<service auth>" },
  "action":       "dpp.spec.update",
  "object":       { "type": "dpp", "id": "<ulid>" },
  "binding":      { "parent_type": "resource", "parent_id": "<id>",
                    "epoch": <int> },
  "operation_digest": "sha256:<hex>",
  "issued_at":    "<rfc3339>"
}
```

- `principal` is the §2 verified principal. Not a header.
- `action` and `object.id` come from the handler and the path, not the body.
- `binding.parent_id` is loaded by the service from the object's **immutable
  binding** (e.g. the resource a DPP was created against), never from the new
  request payload (§4.2).
- `operation_digest` lets the PDP tie its answer to the exact bytes the PEP
  will execute, and lets the audit log (`zf_permission_log`) record it.

### 4.2 Response (PDP → PEP)

```
{
  "request_id":      "<echo>",
  "decision":        "allow" | "deny",
  "reason_code":     "ok" | "not_controller" | "stale_epoch" | ... ,
  "policy_version":  "<string>",
  "permission_epoch": <int>,
  "obligations":     { "allowed_fields": [...], "allowed_sections": [...],
                       "expiry": "<rfc3339>" }
}
```

- `reason_code` is non-sensitive (no "because resource X is owned by user Y").
- `obligations` may narrow a broad allow: e.g. a repair role may update some
  DPP sections but not others. The PEP MUST enforce obligations, not just the
  allow/deny bit.

### 4.3 Non-negotiable properties

1. **The handler fixes the action; the service loads the parent.** A client
   cannot pick a weaker action or a different parent to reach a privileged
   path (§3, §4.1).
2. **A service asserting `subject=Alice` does not prove Alice authorized
   this.** The verified principal (§2) is the proof. A service that needs to
   act *for* a user carries either that user's own signature or an
   operation-scoped delegated assertion in `delegation`; a bare header or a
   service's say-so is rejected. This is the §2 "principal from a header"
   defect, stated as a rule.
3. **Fail closed.** PDP timeout, transport error, or an invalid/unparseable
   decision ⇒ **deny** (retry-safe). Never fall back to the pre-contract path.
4. **An online check is not a transaction.** The allow is a decision at an
   epoch, not a lock; already-authorized in-flight operations are governed as
   the architecture review ch. 09 describes. The PEP records
   `policy_version`/`permission_epoch` with the operation for audit.

## 5. What P0 (the first slice) implements of this contract

The decision document's first slice is **the contract + authentication of the
DPP writes**. Concretely, against this contract:

- **Fully:** §2 properties 1–3 (signature required, DID resolves, object-id
  bound to path) on `UpdateDPP`, `UpdateDPPStatus`, `DeleteDPP`,
  `DeleteAttachment`, reusing the same `VerifyDid`+`IsAuth` the other DPP
  handlers already call, extracted into one shared helper so the copy the
  decision doc criticizes shrinks rather than grows.
- **Shape only, enforcement as fast-follow:** §2 property 4 (nonce/TTL replay
  defense) — the signed-payload envelope carries the fields and the PEP logs
  them; rejection is turned on once clients emit them.
- **Not yet:** §3 PDP wiring and §4 request/response — these need the Elixir
  PDP side, which is a later slice. Until then the DPP writes are
  *authenticated* (a valid DID signature bound to the object) but not yet
  *authorized against the resource controller*. The PR says this in those words
  so no one mistakes authn for authz.

## 6. Conformance: the shared test vectors

`docs/cross-service-authz/` holds declarative cases both the Go PEP
and the Elixir PDP suites consume. Each vector is `{ "name", "layer",
"input", "expect" }`:

- `layer: "authn"` — executable now, against the PEP alone (no PDP). These are
  the P0 cases.
- `layer: "contract"` — need the PDP; they pin behaviour for the later slice
  and MUST NOT silently pass before the PDP exists (a runner skips them with a
  visible "pending PDP" marker, never a green).

See `docs/cross-service-authz/README.md` for the schema and the
runner contract. The vectors are the source of truth; this prose is their
explanation.
