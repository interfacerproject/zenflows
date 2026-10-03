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

# Processes, intents and proposals (RBAC slice 3) — design

- **Date:** 2026-10-03
- **Status:** Draft, awaiting review
- **Builds on:** `docs/authz-foundation-design.md` (slice 1, PR #71) and
  `docs/authz-events-design.md` (slice 2, PR #72); this work is on
  `feat/authz-processes`, stacked on `feat/authz-events`.

## 1. Goal

After slice 2, events are authorized, but the objects around them are not:
any signer can edit or delete anyone's process, proposal or intent, attach
events and intents to anyone's process, link anyone's intents to any
proposal, and create satisfactions between unrelated events and intents.

This slice gives processes, proposals and intents a controller, and decides
the 14 mutations of this family (process ×3, proposal ×3, intent ×3,
`proposeIntent`, `deleteProposedIntent`, satisfaction ×3) plus the
attachment of events and intents to processes.

Milestone wording after this slice: "CRUD, events, processes, intents and
proposals enforced; groups, plans, agreements and catalogue types pending".

## 2. Control

### 2.1 Object control

A new table `zf_object_control` records the administrative controller of a
**process**, **proposal** or **intent**, in the same spirit as slice 1's
`zf_resource_control`:

| Column | Type | Notes |
|---|---|---|
| `target_type` | text, `CHECK IN ('process','proposal','intent')` | part of PK |
| `target_id` | uuid | part of PK; no FK (polymorphic) |
| `controller_id` | uuid, FK → `vf_agent` | |
| `source` | text, `CHECK IN ('creation','admin')` | |
| `epoch` | integer, default 0 | |
| `updated_at` | timestamptz | repo timestamps convention |

`zf_resource_control` is unchanged.

### 2.2 Creation

- A Person creating a process, proposal or intent becomes its controller
  (`source: creation`); these objects carry no agent field, so there is no
  organization case.
- Service principals (`:import`, `:migration`) create without a control row
  (as for resources); `:anonymous` follows slice 1 (`UNAUTHENTICATED` unless
  `allow_unchecked`).
- Each control row writes one `object_control.set` permission-log entry
  (`target_type`, `target_id`, `subject_id: controller`,
  `after: %{controller_id, source, target_type}`).

### 2.3 Legacy objects

Processes, proposals and intents created before this slice have no control
row: **deny-all** for every controller action and for attachment (team
decision, consistent with slice 1). The party-based rules in §3 (intent
updates by a named party, satisfactions) still apply, so old contribution
proposals can still be accepted or rejected.

Admin-key mutation `assignObjectControl(targetType: String!, targetId: ID!,
personId: ID!, reason: String!)` creates or replaces a control row
(`source: admin`, `epoch + 1`), logged as `object_control.set` with the
reason.

### 2.4 Deletion

Deleting a process, proposal or intent removes its control row in the same
transaction and logs `object_control.remove` (`before: %{controller_id,
source, epoch, target_type}`).

## 3. Rules

"Acts for X" is as in slice 2: X is the signer, or an Organization in which
the signer is an active `org.admin`. "Controls O" means O's control row
exists and the signer acts for its `controller_id`.

| Mutation | Allowed when (Person) |
|---|---|
| `createProcess` | always |
| `updateProcess`, `deleteProcess` | signer controls the process |
| `createProposal` | always |
| `updateProposal`, `deleteProposal` | signer controls the proposal |
| `createIntent` | if `inputOf`/`outputOf` is set: signer controls that process (the intent may then name only the other party); otherwise signer acts for the provider or the receiver |
| `updateIntent` | signer controls the intent, or acts for its provider or receiver, or — **only when the update sets nothing but `finished: true`** — acts for a provider or receiver of any intent published in the same proposal (§3.1) |
| `deleteIntent` | signer controls the intent |
| `proposeIntent` | signer controls the proposal **and** (controls the intent or acts for its provider or receiver) |
| `deleteProposedIntent` | signer controls the proposal |
| `createSatisfaction` | `satisfiedByEvent` set; signer acts for the event's provider or receiver; and the event's {provider, receiver} intersects the intent's {provider, receiver} (nils ignored). `satisfiedByCommitment` → denied (commitments are not exposed). |
| `updateSatisfaction`, `deleteSatisfaction` | signer acts for the provider or receiver of the satisfying event |

Service principals: `:import` and `:migration` gain `process.create`,
`intent.create`, `proposal.create`; the admin key gains
`object_control.assign`.

### 3.1 Finishing a proposal's intents

The SDK's `rejectProposal` marks all three intents of a contribution
proposal `finished`, signed by the owner, who is not a party of the `cite`
intent (its only party is the proposer). The same-proposal `finished` rule
keeps this working without letting anyone change anything else on those
intents. `acceptProposal` does not update intents.

### 3.2 Process rule for events (extends slice 2)

An event with `inputOf` or `outputOf` must reference a process the signer
controls; otherwise `FORBIDDEN` (telemetry rule `:process`). Legacy
processes therefore cannot receive new events from persons. Services and
unchecked anonymous calls are unaffected.

Unchanged and still unchecked: `groupedIn` / `plannedWithin` / `basedOn` /
`nestedIn` on processes (groups, plans, specifications and scenarios are
pending).

## 4. Write paths

Every protected domain function takes `%ExecutionContext{}` first and
follows the slice-1 shape (authorize → target → write → log in one
`Ecto.Multi`):

- **Process, Proposal** — create: insert, then `ObjectControl.Domain
  .multi_on_create/4`; update/delete: `Facts.for_object(repo, ctx, type,
  id)` (target row `FOR UPDATE`, control row `FOR UPDATE`, `admin_of`
  for the controller).
- **Intent** — create: facts from the validated changeset (process control
  row `FOR SHARE` if a process is referenced; `admin_of` for provider,
  receiver and the process controller); update/delete:
  `Facts.for_intent/3` (intent `FOR UPDATE`, its control row `FOR UPDATE`,
  parties of the intents published in the same proposals, unlocked).
- **ProposedIntent** — proposal control row `FOR SHARE`, intent and its
  control row.
- **Satisfaction** — event and intent (unlocked; their parties are
  immutable), satisfaction row `FOR UPDATE` for update/delete.
- **Events** — `EventFacts.load` loads the control rows of `inputOf` /
  `outputOf` `FOR SHARE` after resource control rows and before admin rows;
  `EventPolicy` adds the process rule.

### 4.1 Lock order

Resource rows → resource control rows → object control rows (`FOR SHARE`
for decisions, `FOR UPDATE` only by the object's own update/delete and
`assignObjectControl`) → admin rows (`FOR SHARE`). Object-control writers
never lock resource rows, so no cycle with events. `deleteProcess` racing an
event that references it can hit the foreign-key deadlock already
documented in slice 2 (PostgreSQL aborts one; both outcomes are errors).

## 5. GraphQL contract

- The 14 mutations get `meta authz` and leave the guard's pending list.
- New: `assignObjectControl` (admin key, §2.3) and guest query
  `objectControl(targetType: String!, targetId: ID!) { controller { id }
  source epoch }`.
- No input/output shape changes to existing mutations.
- Errors: `FORBIDDEN` / `UNAUTHENTICATED`; telemetry rules gain `:process`,
  `:control`, `:party`.

## 6. Compatibility

Checked against `interfacer-client/src/resources/ResourceClient.ts` and
`src/graphql/operations.ts`:

| Flow | Expected |
|---|---|
| createProject / machine / DPP, updateMetadata, relocate, fork | allowed: the signer creates the process first |
| contributeToResource (owner adds contributors at project creation) | allowed: owner's process |
| proposeContribution (proposer) | allowed: own process, proposal and intents |
| acceptProposal (owner) | allowed: own new process; satisfactions satisfy §3 |
| rejectProposal (owner) | allowed: party of accept/modify intents; cite intent via §3.1 |
| sale proposal (createProposal, two intents, proposeIntent) | allowed: seller is party of both intents and controls the proposal |
| attaching to a process created before the upgrade | denied (legacy deny-all) |

## 7. Scope boundaries

Out of scope: ProcessGroup, Plan, Scenario, ScenarioDefinition, Agreement,
catalogue types (ResourceSpecification, ProcessSpecification, Unit,
SpatialThing, Recipe*, RoleBehavior, ProductBatch), commitments, read
privacy (F05).

## 8. Migration and rollout

- One additive migration creating `zf_object_control`; no backfill.
- Enforced under the existing `AUTHZ_ENFORCE` gate.
- Release notes: legacy deny-all and `assignObjectControl`; other agents'
  processes/proposals/intents become read-only; the updated "still pending"
  list.

## 9. Testing

- **Policy unit tests:** each new action × {controller, admin of controlling
  org, named party, stranger, no control row}; intent create with/without
  process; satisfaction agent-overlap; `finished`-only same-proposal rule
  (and that any other field is denied on that path).
- **Domain Alice/Bob:** Bob cannot update/delete Alice's process, proposal,
  intent; cannot attach an event or intent to Alice's process; cannot
  create a process-less intent naming only Alice; cannot satisfy Alice's
  intent with an event he is not party to or that shares no agent; cannot
  add his intent to Alice's proposal; legacy objects deny-all;
  `assignObjectControl` lifts it and is logged with the reason; deletes
  remove control rows.
- **GraphQL:** proposeContribution → acceptProposal, proposeContribution →
  rejectProposal and the sale proposal, shaped as the SDK sends them.
- **Concurrency:** event attaching to a process vs `assignObjectControl` on
  it; intent `finished` update vs `deleteIntent`.
- **Guards:** pending list shrinks by 14; no orphan control rows after
  deletes; log-content allowed keys gain `target_type`.
- **Test churn:** domain create functions of these types gain `ctx`;
  `Factory.insert!(:process)` processes have no control row, so tests that
  attach a person's event or intent to a process use a new
  `Factory.insert_process!(person)` helper (domain create with that
  person's context).

## 10. Acceptance

All tests in §9 pass; the full suite fails only on the known baseline;
release notes updated.
