<!--
SPDX-License-Identifier: AGPL-3.0-or-later
Zenflows is software that implements the Valueflows vocabulary.
Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

# Event authorization (RBAC slice 2) — design

- **Date:** 2026-10-01
- **Status:** Draft, awaiting review
- **Builds on:** `docs/authz-foundation-design.md` (slice 1, PR #71,
  branch `feat/authz-foundation`); this work is on `feat/authz-events`.
- **Source:** Interfacer architecture review, finding F02 ("economic
  invariants based on declared agents"), threat-model row "unauthorized
  transfer", test cases T12/T14.

## 1. Goal

Slice 1 protects CRUD writes. `createEconomicEvent` still trusts the
`provider`/`receiver` declared in the input: ValueFlows checks compare the
declared provider to the resource's `primaryAccountable`/`custodian`, but
nothing ties either agent to the signer. Bob can therefore emit events in
Alice's name, or change Alice's resources through events.

This slice makes every event write a decision on **who signs**, **whom they
act for**, and **which resources the event changes**, decided before the
event is written, in the same transaction, with row locks.

Milestone wording after this slice: "CRUD and events enforced; processes,
intents and proposals pending".

## 2. Rules

### 2.1 Acting for an agent

The signer *acts for* agent X when X is the signer, or X is an Organization
in which the signer holds an active `org.admin` relationship (slice 1
membership). No other delegation exists in this slice.

### 2.2 Agent rule

For `event.create`, the signer must act for the event's **provider or its
receiver** (team decision). For `event.update`, the same rule applies to
the stored event's provider and receiver.

### 2.3 Resource rule

For every resource the event **changes** (§3), the signer must act for the
resource's controller (`zf_resource_control.controller_id`). A changed
resource without a control row is deny-all (slice 1 rule).

If a changed resource is a container (`contained_in_id` of other resources
points at it), each contained resource is also changed (custody and
accountability cascade in `handle_insert`) and must satisfy the same rule.

Referenced resources (`cite`, `use`) need no control: the event only links
lineage (`previous_event_id`), it does not change quantities, custody or
accountability.

### 2.4 Claim rule

`AUTHZ_CLAIMABLE_AGENTS` lists agent ids (e.g. the LOSH import agent) whose
resources anyone may claim. When the source resource's controller is a
claimable agent, the resource rule for that source is replaced by:

- action is `transfer`, `transferAllRights` or `transferCustody`;
- the event creates a **new** destination resource
  (`toResourceInventoriedAs` absent);
- the signer acts for the **receiver**;
- the source is not a container.

Every successful claim writes one `resource.claim` permission-log row.
This keeps `interfacer-gui/pages/resource/[id]/claim.tsx` working.

### 2.5 Controller of created resources

- `raise`, `produce`: slice 1 rule (verified creator; the receiving
  organization when the creator is its admin).
- `transfer`, `transferAllRights`, `transferCustody`, `move` creating a new
  destination: the **receiver** is the controller (team decision; the
  provider gave the resource away). This replaces slice 1 behaviour for
  these actions.

### 2.6 Service and anonymous principals

- Service principals: `event.create` is added to the `:import` and
  `:migration` action sets; resource and agent rules do not apply to them
  (they are fixed-scope, server-side).
- Anonymous: unchanged from slice 1 — `UNAUTHENTICATED` unless
  `AUTHZ_ALLOW_UNCHECKED=true` (refused in production), in which case
  everything is allowed.

## 3. Action table (`Zenflows.Authz.EventPolicy`)

A pure module. `touched/1` takes the validated event changeset's changes
and returns `%{changes: [resource_id], references: [resource_id], creates:
:none | :resource | :destination}`.

| Action | Changes | References | Creates |
|---|---|---|---|
| `raise`, `produce` | existing `resourceInventoriedAs` if given | — | new resource when `resourceConformsTo` is given |
| `lower`, `consume`, `accept`, `modify`, `pickup`, `dropoff` | `resourceInventoriedAs` | — | — |
| `transfer`, `transferAllRights`, `transferCustody`, `move` | `resourceInventoriedAs`; `toResourceInventoriedAs` if given | — | new destination when `toResourceInventoriedAs` is absent |
| `cite`, `use` | — | `resourceInventoriedAs` | — |
| `work`, `deliverService` | — | — | — |
| `combine`, `separate` | — | — | — (denied: no implementation in `handle_insert`) |

For `raise`/`produce` with an existing `resourceInventoriedAs` (increment
an existing resource), that resource is changed.

A guard test fails if any id in `Zenflows.VF.Action.map/0` is missing from
the table.

## 4. Write path

In `EconomicEvent.Domain.multi_insert(m, ctx, key, evt_params, res_params)`:

1. **Validate** — build `EconomicEvent.changeset(evt_params)`. Invalid →
   return the changeset error unchanged (no locks, no authorization).
2. **Load facts** — `Zenflows.Authz.EventFacts.load(repo, ctx, changes)`:
   - changed and referenced resource rows, plus resources contained in
     changed ones, `FOR UPDATE`, **in ascending id order**;
   - their `zf_resource_control` rows `FOR UPDATE`, ascending id order;
   - `Facts.admin_of(repo, ctx, ids)` `FOR SHARE` with
     ids = provider, receiver, and every changed resource's controller;
   - whether each source controller is claimable (from config).
3. **Decide** — `EventPolicy.authorize(ctx, changes, facts)` (pure),
   called through `Zenflows.Authz.authorize/4` so `enforce`,
   `allow_unchecked` and deny telemetry behave as in slice 1. Deny aborts
   the multi before the event row exists.
4. **Write** — existing `Multi.insert` of the event and `handle_insert`
   (ValueFlows checks unchanged). Transfer-type creations call
   `ResourceControl.Domain.multi_on_create/4` with
   `controller: evt.receiver_id`.
5. **Log** —
   - each new control row: `resource_control.set`,
     `after: %{controller_id, source, event_id}`;
   - each claim: `resource.claim`, `target_type: "economic_resource"`,
     `target_id: <source>`, `before: %{controller_id: <claimable agent>}`,
     `after: %{controller_id: <claimer>, event_id, resource_id: <new>}`.
   Ordinary event effects are not permission changes; the event is their
   record.

`updateEconomicEvent`: load the event `FOR UPDATE`, `admin_of` for its
provider and receiver, apply §2.2. Missing event → `FORBIDDEN` for persons.

### 4.1 Lock order

Resource rows (ascending id) → control rows (ascending id) → admin rows
`FOR SHARE`. Slice 1 revoke takes org advisory lock → relationship row →
admin rows, and never locks resource rows, so no cycle exists. Two events
touching the same resources in opposite directions lock in the same
(ascending) order.

## 5. GraphQL contract

- `createEconomicEvent`: `meta authz: "event.create"`;
  `updateEconomicEvent`: `meta authz: "event.update"`; both removed from
  the guard's pending list.
- Denials: `FORBIDDEN` / `UNAUTHENTICATED` as in slice 1; no detail on which
  rule failed.
- No input or output shape changes.

## 6. Configuration

`AUTHZ_CLAIMABLE_AGENTS` — comma-separated agent ULIDs, default empty, read
in `conf/runtime.exs` into `config :zenflows, Zenflows.Authz,
claimable_agents: [...]`. Each id must be a valid ULID or the application
refuses to start (all environments). Ids that are not existing agents are
allowed (logged as a warning at boot).

## 7. Telemetry

`[:zenflows, :authz, :deny]` metadata gains `rule: :agent | :resource |
:claim | :unsupported`. Never includes event bodies.

## 8. Scope boundaries

Out of scope (later slices):

- authorization of processes, process groups, intents, proposals,
  proposed intents, satisfactions, agreements (still pending mutations);
  attaching an event to another agent's process remains possible;
- a first-class `Delegation` (purpose, expiry, non-transitive);
- consent for receiving (a provider may give to any receiver);
- implementing `combine`/`separate`, or setting containment;
- read privacy (F05).

## 9. Compatibility

Checked against `interfacer-client/src/graphql/operations.ts` and
`interfacer-gui`:

| Flow | Signer | Expected |
|---|---|---|
| Create project (`produce`, provider = receiver = me, new resource) | me | allowed |
| Update metadata (`accept`/`modify` on my resource) | me | allowed if I control it (org-owned backfilled resources need an assigned org admin) |
| acceptProposal `cite` (provider = proposer, receiver = owner, proposer's fork) | owner | allowed (receiver; reference only) |
| acceptProposal `accept`/`modify` on origin | owner | allowed if owner controls origin |
| LOSH claim (`transfer` LOSH → me, new resource) | me | allowed once `AUTHZ_CLAIMABLE_AGENTS` contains the LOSH id; denied otherwise |
| Bob transfers Alice's resource to himself | Bob | `FORBIDDEN` (resource rule) |
| Bob raises/works with provider = receiver = Alice | Bob | `FORBIDDEN` (agent rule) |

Behaviour change vs slice 1: resources created by transfer-type events are
controlled by the receiver; the slice-1 test asserting the creator is
updated.

## 10. Testing

- **EventPolicy unit table:** every action × signer relation (self, admin
  of provider org, admin of receiver org, stranger) × resource control
  (controls, does not, no row) × claim cases (listed/unlisted agent, new vs
  existing destination, receiver self vs other, container source).
- **Domain Alice/Bob per action family:** Bob cannot raise/produce/work in
  Alice's name; cannot lower/consume/accept/modify/pickup/dropoff/transfer*
  /move Alice's resource as provider or as receiver; can cite/use Alice's
  resource in an event where he is provider or receiver; an admin of the
  controlling org can act; a revoked admin cannot; a container whose
  contents someone else controls blocks the transfer; combine/separate are
  denied.
- **Claim:** allowed only per §2.4; one `resource.claim` log row; denied
  with an empty list; new resource controlled by the claimer.
- **Transfer controller:** destination created by a transfer is
  controlled by the receiver; log row carries `event_id`.
- **updateEconomicEvent:** provider/receiver may update descriptive fields;
  a stranger cannot; missing id → FORBIDDEN.
- **GraphQL:** acceptProposal-shaped and claim-shaped documents succeed;
  T12/T14-style negatives return FORBIDDEN with data unchanged.
- **Concurrency:** opposite transfers between the same two resources do not
  deadlock; an event racing a revoke of the signer's admin role is
  serialized (event waits, then is denied).
- **Guards:** every Action id is in the table; create/updateEconomicEvent
  carry `meta authz`; log-content allowed keys gain `event_id` and
  `resource_id`.
- **Config:** invalid `AUTHZ_CLAIMABLE_AGENTS` entry refuses start.

## 11. Acceptance

- All tests in §10 pass; full suite fails only on the known baseline.
- Release notes updated: event rules, claim setup (`AUTHZ_CLAIMABLE_AGENTS`
  must contain the LOSH agent id before deploy), receiver control for
  transfers, and the new "still pending" list.
