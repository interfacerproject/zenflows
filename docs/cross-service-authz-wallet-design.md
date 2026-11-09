# Cross-service authorization: wallet issuance (event-backed)

Workstream: interfacerproject/zenflows#74 (non-closing reference).
Status: **design, awaiting owner review 2026-10-21**. Feature branches /
draft PRs only; no change to `main`/`master` of gui or zenflows.

The fourth and largest service in the cross-service authz tranche, after
DPP, feedback and inbox. Decisions locked with the owner:
**all seven point-events**, the **current `PointsDistribution` schedule
adopted as-is** server-authoritative, and **per-authority attestation**.

## 1. What exists, and the gap this closes

The wallet holds two economic point balances per agent — *Idea* and
*Strengths*. Its one write, `POST /token` → `addTokensHandler`, calls
`storage.AddDiff(owner, token, amount)` with **`owner`, `token` and
`amount` all read from the request body**. The GUI (`WalletClient.addPoints`,
`interfacer-gui/lib/PointsDistribution.ts`) awards fixed amounts at
ValueFlows coordination moments:

| Event (GUI enum) | Points | Recipient pattern today |
|------------------|-------:|-------------------------|
| OnFork           | 100    | owner ← Idea, actor ← Strengths |
| OnCreate         | 100    | owner ← Idea, actor ← Strengths |
| OnContributions  | 100    | owner ← Idea, actor ← Strengths |
| OnAccept         | 100    | owner ← Idea, actor ← Strengths |
| OnCite           | 100    | owner ← Idea, actor ← Strengths |
| OnStar           | 10     | owner ← Idea, actor ← Strengths |
| OnWatch          | 10     | owner ← Idea, actor ← Strengths |

The gap is **unbacked minting**: a single valid signature authorizes
creating *any amount* of *any token* for *any owner*. There is no
server-side check that the triggering event happened, that the recipient is
entitled, or that the amount matches. A signer can mint themselves unlimited
economic points, or credit anyone. This is the ratified constraint from the
field guide — *"wallet issuance must come from a verified economic event"* —
not yet honored. The PDP already reserves `wallet.points.issue` in its
action registry (`@actions`), unused.

## 2. Decisions (owner, 2026-10-21)

- **Coverage:** all seven event types, not a thin subset.
- **Schedule:** adopt the current `PointsDistribution` amounts (100 / 10)
  and the *owner ← Idea / actor ← Strengths* split **as-is**, moved to the
  server as the authoritative source of truth. (The split's economics — the
  resource owner earning on another agent's fork — is accepted as current
  behavior; see §6 open items, flagged not blocking.)
- **Verification:** **per-authority attestation** — each event is confirmed
  by the service that owns it, not mirrored into one ledger.

## 3. The two authorities

The seven events do not live in one place:

| Event | Owning authority | Backing record |
|-------|------------------|----------------|
| fork / create / contributions / accept / cite | **Zenflows** (REA) | `EconomicEvent` (`action_id` produce/work/cite/transfer…) and the RBAC contribution mutations (#75–77); fork via resource lineage (`previous`) |
| star | **Inbox** | a `Like` row in the `liked` tarantool space (stable uint64 id) |
| watch | **Inbox** | a `Follow` row in the `follow` space (stable uint64 id) |

A single Zenflows PDP cannot attest a star/watch (it cannot see inbox's
tarantool). So issuance verification is **per-authority**: the wallet asks
the owning service to attest the event before minting.

## 4. Architecture: event-backed issuance

The wallet becomes a PEP whose write references the **triggering event**, not
a free amount. It mints only what the owning authority attests.

### 4.1 Request shape

`POST /token` changes from `{owner, token, amount}` to an **event
reference** plus the existing DID proof:

```json
{
  "event": { "authority": "zenflows" | "inbox",
             "type": "accept" | "fork" | ... | "star" | "watch",
             "id": "<event/like/follow id in that authority>" },
  "request_id": "<opaque>"
}
```

`owner`, `token` and `amount` are **removed from the client's control**.

### 4.2 Attestation

- **Zenflows events** (`fork`/`create`/`contributions`/`accept`/`cite`):
  the wallet calls the Zenflows PDP, extended with a `wallet.points.issue`
  **fact loader** that, given `(type, id)`, verifies the event exists, is of
  a point-earning kind, derives the **recipient(s)** from the event (resource
  `primaryAccountable` as owner; the acting agent), looks up the
  **server-side amount** from the schedule, and enforces **idempotency** (the
  event has not already paid out). It returns the payout(s) to mint, or a
  fail-closed deny.
- **Inbox events** (`star`/`watch`): the inbox gains a small **attestation
  endpoint** that, given a `liked`/`follow` id, confirms the row exists and
  its actor, applies the schedule amount, marks the row **paid** (idempotency
  column), and returns the payout — or denies. The wallet calls it the same
  way it calls the PDP.

In both cases the attesting authority re-verifies the acting user's own
signature (the DID proof the wallet forwards), consistent with contract
§4.3 property 2.

### 4.3 The wallet PEP

- Forwards the event reference + the DID proof to the right authority.
- Mints **exactly** the attested payout(s) (`AddDiff` per recipient/token),
  nothing from the body.
- Fails closed: no attestation, a deny, an already-paid event, a transport
  error or an unreachable authority → **403/deny**, nothing minted.
- The authoritative **schedule** (amounts + recipient split) lives on the
  server side (Zenflows for its five, inbox for its two), ported verbatim
  from `PointsDistribution.ts`.

### 4.4 GUI / SDK

`WalletClient.addPoints(owner, token, amount)` becomes
`issueForEvent(eventRef)` — the GUI stops computing and sending amounts and
owners, and instead names the event it just caused. This is a breaking SDK
change (unlike feedback/inbox, which were server-only), so it ships with a
coordinated `interfacer-client` + `interfacer-gui` update.

## 5. Idempotency (the load-bearing property)

Economic points must mint **once** per event. Each authority keys a payout
on its own event id and records that it paid:

- Zenflows: a payout ledger keyed on the `EconomicEvent`/mutation id (the
  RBAC mutations are already idempotent, giving stable ids).
- Inbox: a `paid` marker on the `liked`/`follow` row.

A replay of an issuance request for an already-paid event is a deny, not a
second mint.

## 6. Honest limitations & open items

- **To verify (not yet pinned in this design):** the exact Zenflows record
  and id for each of fork / create / contributions / accept / cite, and the
  precise recipient derivation per `action_id`. The plan's first task is a
  spike that pins one real event (an accepted contribution) end-to-end before
  the rest are wired. Marked, not assumed.
- **Recipient split** (owner ← Idea, actor ← Strengths) is adopted as-is;
  whether the owner should earn on another agent's fork is a product question
  flagged for later, **not blocking** this slice.
- **Inbox attestation endpoint is new** — star/watch had no payout notion;
  the endpoint and the `paid` marker are part of this slice.
- **Replay / service credential:** inherited tranche limitations — no signed
  nonce envelope, no per-service credential; endpoints internal.
- **Amounts are integers ×100** as today (the GUI divides by 100 on read).

## 7. Scope boundaries (YAGNI)

**In:** the event-backed `POST /token`; the Zenflows `wallet.points.issue`
fact loader + server-side schedule for the five REA events; the inbox
attestation endpoint + `paid` marker for star/watch; idempotent payout
records; the coordinated GUI/SDK change; fail-closed enforcement.

**Out:** changing the point *economics* (amounts/recipients stay as today);
balance reads (already public); a unified cross-service event bus (per
authority, not centralized); the Medusa integration (separate workstream).

## 8. Files (anticipated)

- **zenflows** (`feat/authz-wallet-pdp`, off `feat/authz-pdp`):
  `src/zenflows/authz/pdp.ex` (wallet.points.issue fact loader + schedule),
  contract vectors; the point schedule as a module.
- **zenflows-wallet** (`feat/authz-event-backed`, off `main`): event-ref
  request, attestation client, mint-from-attestation, fail-closed; `.env`.
- **zenflows-inbox** (`feat/authz-attest`, off the merged outbox branch):
  attestation endpoint + `paid` marker on `liked`/`follow`.
- **interfacer-client** + **interfacer-gui**: `issueForEvent`; stop sending
  owner/amount.

## 9. Testing posture

Pure, table-tested policy (schedule lookup, recipient derivation,
idempotency decision) separated from I/O, per the tranche pattern. Each
authority's attestation verified with stubs; the live
event-lookup/idempotency is integration-tier. A first spike proves one
accepted-contribution payout end-to-end before the remaining events.

---

## Appendix: accept event (spiked, Task 1)

`Zenflows.VF.Proposal.Contribution.accept(ctx, proposal_id)` (zenflows
`src/zenflows/vf/proposal/contribution.ex`) returns:

```
%{proposal, cite_event, accept_event, modify_event}   # all EconomicEvent
```

- **Idempotent.** `state/2` detects an already-accepted proposal and returns
  its existing events, writing nothing; a `:pending` proposal writes them
  once in a transaction. So re-accepting yields the **same** `accept_event.id`.
- **Payout key:** `accept_event.id` — stable across retries; the wallet
  payout store dedupes on it.
- **Roles** (from `shape/1`): `owner = accept.receiver_id` (resource owner
  who accepts), `contributor = cite.provider_id` (proposer whose fork was
  contributed), `origin`/`fork` the two resources.

### Ruling (Task 1): accept recipients + amount for the vertical

The GUI's OnAccept mapping is buggy (`proposal/[id].tsx` credits the owner
twice, with the Idea/Strengths enums swapped, and gives the contributor
nothing). For the accept vertical the PDP schedule credits, derived from the
event roles:

- `contributor (cite.provider_id)` ← **strengths**, 10000 (100 ×100)
- `owner (accept.receiver_id)` ← **idea**, 10000

**Why:** corrects the swap, rewards the contributor whose work was accepted
(the economic point of contribution rewards), keeps the owner's curation
credit. **Cost if wrong:** a config-level change to the schedule module;
architecture is unaffected (recipient/amount are data, not structure). The
authoritative cross-event economics (all 7 events, who earns what) remains
the deferred product decision (spec §6); this vertical fixes only `accept`.
