# Wallet event-backed issuance — Phase 1 (`accept` vertical) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Prove the event-backed wallet architecture end-to-end on ONE event — `accept` (acceptContribution) — so a point issuance is minted only when the Zenflows PDP attests the real acceptance event, with the amount and recipient derived server-side and paid at most once.

**Architecture:** The wallet stops minting from body `{owner,token,amount}`. A `POST /token` names the triggering event `{type:"accept", id}`; the wallet forwards it + the DID proof to the Zenflows PDP; the PDP verifies the acceptance event, derives recipients + server-authoritative amounts from a schedule module, enforces one-payout idempotency, and returns the payouts; the wallet mints exactly those. Fail closed.

**Tech Stack:** Elixir (Zenflows PDP), Go (zenflows-wallet, tarantool), TypeScript (interfacer-client/gui).

**Spec:** `docs/cross-service-authz-wallet-design.md`

## Global Constraints

- No `main` changes to gui/zenflows; feature branches + draft PRs only; no deploy.
- Branches: `feat/authz-wallet-pdp` (zenflows, off `feat/authz-pdp`); `feat/authz-event-backed` (zenflows-wallet, off `main`); `feat/wallet-issue-event` (interfacer-client, off `main`); gui change optional in this phase (see Task 6).
- Attribution: commits end `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`; PRs end `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Toolchain: Elixir via standalone ExUnit runners (full `mix test` not runnable locally); Go via Docker (`inbox-go`-style image; wallet uses tarantool/go-openssl cgo → needs libssl-dev, bookworm base). Amounts are integers ×100.
- Fail closed everywhere: no attestation / deny / already-paid / transport error / unreachable → mint nothing.
- **Scope: `accept` ONLY.** The other six events and the full authoritative schedule are a follow-on plan (pending owner ratification of the corrected per-event mapping — see spec §6; the OnAccept token-swap bug is corrected here, not copied).

## Review Focus

- **Idempotency is the load-bearing property:** replaying an issuance for an already-paid accept event must mint nothing. Test a second call is a no-op/deny.
- **Amount & recipient come from the server, never the body:** a request that still carries `owner`/`amount` must have them ignored; the minted values come only from the PDP attestation.
- **The attested event must be real:** a `{type:"accept", id}` for a non-existent or non-accepted proposal must deny (fail closed), minting nothing.
- **Recipient correctness (bug fix):** on accept, Idea → the resource owner, Strengths → the accepting agent (correcting the GUI's token swap); a test pins the token↔recipient mapping explicitly.
- **Wallet fails closed when the PDP is unreachable** (empty/5xx/timeout) → nothing minted.

---

### Task 1: Spike — pin the `accept` event (discovery)

**Files:** none changed. Output: a findings section appended to `docs/cross-service-authz-wallet-design.md` under "## Appendix: accept event (spiked)".

**Interfaces — Produces (documented, consumed by Tasks 2–4):**
- The exact Zenflows record a payout keys on for an accepted contribution, with its stable **id** and schema module.
- The **recipient** fields: resource owner (`primary_accountable_id`) and the accepting agent (`provider_id`/`receiver_id` / the execution-context agent).
- Whether `Contribution.accept/2` is idempotent (re-accept is a no-op) and what id is stable across retries.

- [ ] **Step 1: Read `Zenflows.VF.Proposal.Contribution.accept/2`** (in `src/zenflows/vf/proposal/contribution.ex`, zenflows-accept worktree) and the `EconomicEvent`/records it inserts. Note each inserted record's schema, `action_id`, provider/receiver/resource, and id.
- [ ] **Step 2: Determine the payout key** — the single stable id (the acceptance event id, or the proposal id if acceptance is 1:1 and idempotent) a payout dedupes on. Confirm by reading whether `accept/2` uses `get_by`/unique constraints (idempotent) like the sw_pass flow.
- [ ] **Step 3: Determine recipients** — map "owner" and "accepting agent" to concrete fields on the record(s)/resource. Write the mapping down.
- [ ] **Step 4: Append findings** to the design doc appendix (record id, recipient fields, idempotency handle). This is the interface Tasks 2–4 consume.
- [ ] **Step 5: Commit** (`docs(authz): appendix — spiked accept event for wallet issuance`).

No test (discovery task); the contract is the written appendix.

---

### Task 2: PDP — `wallet.points.issue` schedule + decision for `accept`

**Repo/branch:** zenflows, `feat/authz-wallet-pdp` (off `feat/authz-pdp`).

**Files:**
- Create: `src/zenflows/authz/points_schedule.ex` (the authoritative schedule)
- Modify: `src/zenflows/authz/pdp.ex` (`@actions` + `:issuance` branch in `decide/2`)
- Modify: `docs/cross-service-authz/contract.json` (accept vectors)
- Test: standalone decide runner (as in the feedback slice)

**Interfaces:**
- Consumes: Task 1's recipient/amount facts (passed in `facts` by the loader/vector).
- Produces: `decide/2` for action `wallet.points.issue` returns, on a proven+attested accept, `{"decision":"allow","payouts":[{recipient,token,amount}...]}`; else fail-closed deny.

- [ ] **Step 1: Write `points_schedule.ex`** — a pure module mapping an event type to `{amount, [{role, token}]}`. For `accept`: `amount: 10000` (100 ×100), roles `owner → "idea"`, `actor → "strengths"` (the corrected mapping; the GUI's swap is NOT copied).

```elixir
defmodule Zenflows.Authz.PointsSchedule do
  @moduledoc "Authoritative point schedule (server side). Phase 1: accept only."
  @schedule %{"accept" => %{amount: 10_000, roles: [{:owner, "idea"}, {:actor, "strengths"}]}}
  def for_event(type), do: Map.get(@schedule, type)
end
```

- [ ] **Step 2: Add the failing decide vector** to `contract.json` (`contract.allow.wallet_accept_pays_owner_idea_actor_strengths`): input action `wallet.points.issue`, facts `{principal_proven:true, event:%{type:"accept",paid:false}, owner:"01OWNER", actor:"01ACTOR"}`, expect `allow` with payouts `[{recipient:"01OWNER",token:"idea",amount:10000},{recipient:"01ACTOR",token:"strengths",amount:10000}]`. Add deny vectors: `already_paid` (facts `paid:true` → deny `already_paid`), `event_not_found` (facts `event:nil` → deny `event_not_found`), `unproven_subject`.
- [ ] **Step 3: Run the decide runner — RED** (`wallet.points.issue` unknown → `unknown_action`).
- [ ] **Step 4: Implement** — add `"wallet.points.issue" => :issuance` to `@actions`; a `:issuance` branch in `decide/2` that fails closed unless `principal_proven` and `facts["event"]` present and `paid != true`, then builds payouts from `PointsSchedule.for_event(type)` × `facts` recipients. Return `allow` + `payouts`.
- [ ] **Step 5: Run the runner — GREEN** (all wallet vectors pass; existing vectors unaffected).
- [ ] **Step 6: Commit.**

> `load_facts/1` for `:issuance` (reading the real acceptance event via Task 1's handle, setting `owner`/`actor`/`paid`) is integration-tier (needs DB), verified by code-read; its policy is covered by these vectors.

---

### Task 3: Wallet — idempotent payout store

**Repo/branch:** zenflows-wallet, `feat/authz-event-backed` (off `main`).

**Files:**
- Modify: `storage.go` (a `payouts` tarantool space + `MarkPaid`/`AlreadyPaid`)
- Test: `storage_test.go` (against a test tarantool, or a pure dedup helper if no test DB)

**Interfaces:**
- Produces: `(*TTStorage) AlreadyPaid(eventId string) (bool, error)`; `MarkPaid(eventId string) error`; a payout is recorded once per event id.

- [ ] **Step 1: Write the failing test** for a pure dedup guard `shouldMint(alreadyPaid bool) bool` (mint only when not already paid) — RED.
- [ ] **Step 2: Implement `shouldMint`** + the `payouts` space (`event_id` primary) with `AlreadyPaid`/`MarkPaid`. GREEN on the pure test; the tarantool methods are integration-tier (code-read + the existing `AddDiff` pattern).
- [ ] **Step 3: Commit.**

---

### Task 4: Wallet — event-ref request, attest, mint-from-attestation

**Repo/branch:** zenflows-wallet, `feat/authz-event-backed`.

**Files:**
- Create: `authz.go` (pure `BuildIssueRequest`, `InterpretPayouts` fail-closed), `client.go` (PDP client, ported)
- Modify: `wallet.go` (`addTokensHandler` → event-ref flow)
- Test: `authz_test.go`

**Interfaces:**
- Consumes: Task 2 response (`decision`, `payouts`), Task 3 `AlreadyPaid`/`MarkPaid`.
- Produces: `addTokensHandler` that reads `{event:{type,id}}`, ignores any body owner/amount, calls the PDP, and on allow mints each payout once (guarded by `AlreadyPaid`), then `MarkPaid`.

- [ ] **Step 1: Write failing `authz_test.go`** — `InterpretPayouts`: allow+payouts → mint list; allow+empty → fail closed; deny → fail closed; transport error → fail closed. RED.
- [ ] **Step 2: Implement `authz.go` + `client.go`** (mirror the DPP/feedback client; POST event-ref + proof to `ZENFLOWS_PDP_URL/authz/decide`). GREEN.
- [ ] **Step 3: Rewire `addTokensHandler`** — parse `{event}`; `AlreadyPaid(event.id)` → no-op 200 if paid; else PDP `Decide`; on `!allow` → 403, mint nothing; on allow, `AddDiff` per payout then `MarkPaid(event.id)`. Build + code-read (handler is integration-tier).
- [ ] **Step 4: Commit.**

---

### Task 5: SDK — `issueForEvent`

**Repo/branch:** interfacer-client, `feat/wallet-issue-event` (off `main`).

**Files:** Modify `src/wallet/WalletClient.ts`; Test `src/wallet/WalletClient.test.ts` (if a test harness exists) or a typed unit.

**Interfaces:**
- Produces: `WalletClient.issueForEvent({type, id})` — signs an event-ref body and POSTs to the wallet; no `owner`/`amount` sent. `addPoints` is deprecated (kept as a thin shim that throws, or removed — Task 6 updates callers).

- [ ] **Step 1: Failing test** — `issueForEvent` posts `{event:{type,id}}` with DID signature headers, no `owner`/`amount`. RED.
- [ ] **Step 2: Implement.** GREEN.
- [ ] **Step 3: Commit.**

---

### Task 6: GUI — call `issueForEvent` on accept

**Repo/branch:** interfacer-gui (feature branch off `main`).

**Files:** Modify `pages/proposal/[id].tsx` (the OnAccept call site) and `hooks/useWallet.ts`.

**Interfaces:** Consumes Task 5 `issueForEvent`.

- [ ] **Step 1:** Replace the two `addIdeaPoints/addStrengthsPoints(..., OnAccept)` calls at the accept site with a single `issueForEvent({type:"accept", id:<acceptance/proposal id>})`. The amount/recipient split now lives server-side.
- [ ] **Step 2:** Typecheck/build (`pnpm build` or `tsc --noEmit`). Manual-verify the accept flow calls the new API (no automated GUI test in scope).
- [ ] **Step 3: Commit.**

---

## Notes for the final reviewer

- The correctness of `load_facts/:issuance` reading the real accept event (Task 1's handle) and the wallet/GUI handler wiring are integration-tier (build + code-read); the pure policy (schedule, payout interpretation, idempotency guard) is unit-tested.
- This phase deliberately ships ONE event. Do not generalize the schedule here — the other six events need the owner's ratified mapping (spec §6) and arrive in a follow-on plan.
