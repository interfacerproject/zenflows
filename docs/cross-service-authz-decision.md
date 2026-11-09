# Cross-service authorization: decision document

Workstream: interfacerproject/zenflows#74 (non-closing reference).
Status: **ratified 2026-10-14** (see §7). No code is changed by this document;
it fixes the contract the first slice implements.
It precedes the service work the way `authz-foundation-design.md` preceded
the RBAC slices: it fixes *where decisions live* and *what a decision looks
like*, so that each service's fix is an application of one contract rather
than a new local invention.

Related and important: #78 (contribution `work` events credit the creator,
not the contributor) — the same class of problem, an identity that is
authenticated but whose *right* is never checked.

## 1. Why this document exists

The Zenflows RBAC slices (#71–#73) and the atomic proposal/metadata work on
top gave **one** service a real authorization boundary: a verified actor,
locks, controller/object control, and enforcement inside the transaction.

The other services — DPP, wallet, inbox, feedback — and the proxy in front
of them do **not** share that boundary. They verify, to different degrees,
that the caller *holds a key*. None of them verifies that the caller has the
*right to the object or action*. The result is that a change authorized in
Zenflows and a change made directly against a service answer to different,
weaker rules.

This cannot be fixed the way the earlier tranches were, by writing the
missing check: the missing check needs a *source of truth* those services do
not have, and the source of truth (controllers, memberships, epochs) lives
in Zenflows. So the decision is architectural, and it is the user's to make.
This document states it, with the evidence, and recommends an answer.

## 2. What each service verifies today

Read at the current heads (DPP `5f6ae20`, wallet `f5cf166`, inbox
`963ae1d`, feedback `d905a82`, proxy `10d0734`). "Authn" = proves key
possession; "binds actor" = the proven key is tied to the acting
party for *this* request; "authz" = checks a right to the object/action.

| Service · operation | Authn | Binds actor | Authz | Gap |
| --- | --- | --- | --- | --- |
| **Wallet** `POST /token` (issue points) | yes (DID + signature) | **no** — `owner`/`amount` are body fields, unrelated to the signer | **no** | anyone authenticated can credit any `owner` any amount (review F07) |
| **Wallet** `GET /token/:token/:owner` (balance) | no | — | no | any balance is world-readable |
| **DPP** `POST /dpp`, `POST /upload`, `POST /dpp/:id/attachments` | yes | no (key/`x-user-id` → `createdBy` only) | no | writes tied to a DPP-local `createdBy`, never to the resource's controller (review F03) |
| **DPP** `PUT /dpp/:id`, `PUT /dpp/:id/status`, `DELETE /dpp/:id`, `DELETE /dpp/:id/attachments/:a` | **no** | — | **no** | **state-changing writes with no signature check at all** — verified: these four handlers call neither `VerifyDid` nor `IsAuth` |
| **DPP** `GET /dpp/:id`, `GET /file/:id` | no | — | no | no public/private separation (review F05) |
| **Inbox** `send` | yes (signature vs. `message.Sender`'s key) | **yes** | partial | sender identity is bound; but no policy on what a social activity *means* |
| **Inbox** `read`/`count`/`set-read`/`delete` | yes (signature vs. `Receiver`'s key) | **yes** | partial | receiver identity is bound (this is the best of the set) |
| **Inbox** ActivityPub `POST /:type/:id/inbox`, `/outbox` | **no** | — | no | unauthenticated, and makes **outbound HTTP** to `activity.Actor/Object` — SSRF surface (review F08) |
| **Feedback** (middleware, non-GET) | yes (DID + signature) | **no** — principal is the `x-user-id` header, not the signed key | **no** | sign with your key, claim another `x-user-id` (review F04) |
| **Proxy** (all) | forwards | — | — | adds no trusted principal; presence of the proxy is not required by the services |

Two facts generalize across the table:

1. **Authentication is uniform-ish, authorization is absent.** Every service
   reimplements the same EdDSA-over-Zenroom + DID-resolution check (copied,
   with subtle differences in which header carries the key and whether
   `x-user-id` is required). None asks "may this actor do this to this
   object?".
2. **The principal is often a header, not the signature.** Feedback trusts
   `x-user-id`; DPP writes `createdBy` from `x-user-id`/`did-pk`; the signed
   bytes don't bind it. Inbox is the exception that shows the right shape:
   the signature is verified *against the acting party's own key*.

## 3. The decision to make

**Where does an authorization decision come from?** The architecture review
(ch. 07) lays out six options; the relevant fork for us:

- **A — independent policy per service.** Fast to start, but each service
  grows its own notion of "owner" and "member", revocations diverge, and
  split-brain on grants is permanent. This is roughly where we are.
- **B — every decision in Zenflows.** Authoritative (the data is there), but
  makes Zenflows a god-service that must understand DPP document rules and
  wallet issuance, and blocks all writes when it is down.
- **C — a dedicated authz service.** A new HA component, sync, migrations —
  not justified before the contract even exists.
- **D — a shared library/SDK.** Uniform *procedure*, but it **does not create
  an authority**: the same code in each service still decides locally. One
  Go library also cannot cover Zenflows (Elixir).
- **E — hybrid: authority in Zenflows, local enforcement points (PEPs).**
  Common facts (who controls R, who is an active admin, the current epoch)
  come from Zenflows; each service keeps a thin PEP that asks for the
  decision and applies it, plus its own *more restrictive* document rules.
- **F — a policy engine (OPA/Cedar/OpenFGA).** Worth evaluating only after a
  real scheme and load exist; it does not cure a false principal.

### Recommendation: **E, with D as its delivery mechanism.**

- **Authority = Zenflows (B's data), not a new service (not C).** Controllers,
  object control, memberships and epochs are already modeled and enforced
  there. A DPP or wallet decision that depends on "does Alice control
  resource R" must ask the service that owns that fact.
- **Enforcement = a thin PEP in each service, from a shared library (D).**
  The library is **the PEP, never the PDP**: it standardizes "verify
  signature → build a *verified* principal → ask Zenflows for the decision →
  apply allow/deny + obligations". It removes the copied authn code and the
  header-as-principal mistake, and gives one place to add replay defense
  (nonce/TTL/audience, review F06).
- **Two implementations, not one.** The services are Go; Zenflows is Elixir.
  "Uniform" means *one contract with shared test vectors*, realized as a Go
  library (DPP, wallet, inbox, feedback) and a small Elixir counterpart on
  the Zenflows side that exposes the decision. A single library cannot
  uniform everything — the review says this explicitly (option D row).

This is the direct answer to the user's question ("a Go library that does
server-side what interfacer-client does client-side"): **yes, build it — but
scope it as the shared PEP of the Go services, not as the authorization
itself.** Without §4 first, the library would only make an incomplete check
uniform.

## 4. The decision contract (what must be agreed before code)

A PEP sends, and the PDP (Zenflows) answers, a fixed shape. Draft, to be
ratified:

**Request** — verified principal (the subject proven by the signature, never
a header); optional delegation assertion; the *service* identity (DPP, wallet…)
with its own credential; the registered *action* (e.g. `dpp.spec.update`,
`wallet.points.issue`), derived from the handler, not chosen by the client;
object type and id; the parent/resource binding and its version/epoch; a
digest of the operation; a request id.

**Response** — allow/deny; a non-sensitive reason code; the policy version
and permission epoch; obligations (allowed fields/sections, expiry).

Non-negotiable properties:

- The client **cannot pick a weaker action or a different parent** to reach a
  more privileged handler. The handler fixes the action; the service loads
  the parent from its own validated binding, not from the new payload.
- Sending `subject=Alice` from a service **does not prove Alice authorized
  this**. A verifiable user proof, or an operation-scoped delegated
  assertion, is required — this is exactly the §2 "principal from a header"
  defect, stated as a rule.
- **Fail closed.** Timeout or invalid decision → deny (retry-safe), never a
  fallback to the old unauthenticated path.
- An online check does not make two databases atomic; in-flight
  already-authorized operations are governed as the review's ch. 09 describes.

## 5. Per-service work, once §3/§4 are agreed

Ordered by severity. None of this is done here; it is the backlog this
decision unlocks.

1. **DPP update/delete/status (P0).** They have *no* authentication today.
   First: require the shared authn (as create/upload already do). Then:
   authorize `dpp.*` against the **controller of the bound resource** in
   Zenflows, not `createdBy`. Load the parent from the DPP's immutable
   binding, not the request body.
2. **Wallet issuance (P0/P1).** Bind `owner` to the signer, or — better —
   make issuance an *issuer* action tied to a verified economic event, not a
   free `AddDiff`. Decide who may issue points (see open questions). Close
   world-readable balances if balances are not public.
3. **Feedback principal (P1).** Derive the subject from the signature, not
   `x-user-id`; keep `x-user-id` only as a cross-check that is *logged*, never
   trusted — the shape inbox already uses.
4. **Inbox social routes (P1).** Authenticate the ActivityPub inbox/outbox;
   validate `Actor`/`Object` destinations before any outbound POST (SSRF).
5. **Proxy (P2).** Decide whether it must be the only ingress and whether it
   should attach an attested service identity, or stay a dumb forwarder with
   the services never trusting it.
6. **Shared library (enabler).** Extract the Go PEP once; add replay defense
   and the §4 request builder; ship shared test vectors used by both the Go
   library and the Elixir PDP side.

## 6. What this does *not* decide

- The internal policy of each document action (which `dpp.*` actions exist,
  what `dpp.repair.append` may touch) — that is per-service, more restrictive
  than, and downstream of, this contract.
- Commerce/Medusa authorization (not yet implemented).
- Whether a policy engine (option F) is adopted later.
- The contributor-attribution decision (#78), which is adjacent but is a
  ValueFlows-semantics question, not a cross-service transport one.

## 7. Decisions taken (owner, 2026-10-14)

The owner ratified the following. §7 is now the agreed contract, not a set of
open questions; the per-service backlog in §5 proceeds under these.

1. **Direction: E, with D as its delivery mechanism — confirmed.** Authority
   in Zenflows; thin PEP in each service from a shared library; one contract
   with shared test vectors, realized as a Go library (the Go services) plus a
   small Elixir counterpart on the Zenflows side. This is also the scoped
   "yes" to the Go-library question: it is the PEP, never the PDP.
2. **Wallet issuance: the recommended option — confirmed.** Points may be
   created only by a trusted issuer acting from a *verified economic event*,
   not by a free `AddDiff` with an unbound `owner`. Open issuance (anyone
   authenticated credits anyone) ends; `owner`/`amount` must be derived from
   the event, not from request-body fields chosen by the caller.
3. **Balances are public.** `GET /token/:token/:owner` and the transaction
   history stay world-readable; they need **no** authz. (So the §2 "balance is
   world-readable" row is accepted behaviour, not a defect to close — only
   *issuance* is tightened.)
4. **Proxy: dumb forwarder — confirmed.** It attaches no trusted principal and
   is not required for a decision; the services never trust it. (So §5 item 5
   is settled: no attested-ingress work.)
5. **First slice: the contract (§4) + authentication of the DPP writes (the
   P0).** Not the Go-library extraction as a first visible step. We ratify the
   decision contract and shared test vectors, then make the four unauthenticated
   DPP write handlers require the shared authn, before any PDP wiring.

### What this means for §5

- Item 1 (DPP write-auth) and item 6's *contract + test vectors* part are the
  first slice. The authn step of item 1 lands first; the authz-against-Zenflows
  step follows once the PDP side exists.
- Item 2 (wallet) is now scoped to **issuance binding only**; the
  world-readable balance is **out of scope** by decision 3.
- Item 5 (proxy) is **closed** by decision 4 (stays a dumb forwarder).
- Items 3 (feedback principal) and 4 (inbox social + SSRF) are unchanged.
