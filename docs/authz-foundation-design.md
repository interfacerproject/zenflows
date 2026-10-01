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

# Authorization foundation (RBAC slice 1) — design

- **Date:** 2026-10-01
- **Status:** Draft, awaiting review
- **Baseline commit:** `893489d` (same commit analysed by the Interfacer
  architecture review)
- **Source:** Interfacer architecture review, findings F01, F09 and proposed
  ADR-001/ADR-002 (chapters 04, 08, 09, 12, 16)

## 1. Goal

Today `MW.Sign` verifies the signature and stores the signing Person in
`req_user`, but resolvers and domain functions ignore it: any valid signer can
update or delete another agent's resource, organization or relationship (F01),
and internal callers have no notion of who is acting (F09).

This slice establishes the **minimum verifiable boundary** inside Zenflows:

1. a verified execution context that domain functions must receive;
2. a deny-by-default policy module;
3. administrative control of resources, separate from ValueFlows economic
   fields;
4. organization roles modelled the ValueFlows way (`AgentRelationship` +
   `AgentRelationshipRole`);
5. an append-only trace of every permission change;
6. enforcement on CRUD of resources, organizations, relationships and persons.

**Milestone wording:** "CRUD enforced; events pending". Resources must not be
described as generally protected until the events slice lands (see §7).

## 2. Principles

- **Follow ValueFlows/Zenflows idioms.** Membership and roles are
  `AgentRelationship`s with `AgentRelationshipRole`s, scoped with
  `in_scope_of`. No parallel ACL vocabulary for things VF already models.
- **Economic ≠ administrative.** `primaryAccountable` and `custodian` keep their
  VF meaning. Administrative control lives in its own table.
- **Every permission change leaves a trace**, written in the same transaction
  as the change; nothing permission-related is hard-deleted.
- **Deny by default, fail closed.** Missing context, missing control row or
  unknown action → deny.
- **Decision and write in one transaction**, with row locks on the facts the
  decision used.

## 3. Data model (additive migrations)

### 3.1 `zf_resource_control`

| Column | Type | Notes |
|---|---|---|
| `resource_id` | ULID, PK, FK → `vf_economic_resource` `ON DELETE CASCADE` | one row per resource |
| `controller_id` | ULID, FK → `vf_agent` | Person or Organization |
| `source` | enum `creation \| backfill \| transfer \| admin` | provenance of the current value |
| `epoch` | integer, default 0 | incremented on every change |
| `inserted_at`, `updated_at` | timestamps | |

`transfer` is reserved for the future two-step controller-transfer command; no
code path writes it in this slice.

### 3.2 System roles on `vf_agent_relationship_role`

- Add `system_key` (string, nullable, unique).
- Seed two rows: `org.admin` and `org.member` (labels "admin"/"member",
  inverse labels "has admin"/"has member").
- Policy resolves roles **only by `system_key`**, never by the user-editable
  `role_label`.
- `updateAgentRelationshipRole` / `deleteAgentRelationshipRole` on a row with a
  non-null `system_key` are denied for every principal, including `admin_key`.
  Creating a role with `system_key` is impossible through the API (field not
  exposed).
- `org.member` is seeded so the next slice can use it; in this slice it grants
  no actions.

### 3.3 `vf_agent_relationship`

- Enable the VF `in_scope_of_id` field (currently commented out in the schema),
  nullable, FK → `vf_agent`. For system-role relationships it must equal
  `object_id` (the organization); validated in the changeset.
- Add `revoked_at` (utc datetime, nullable). Active ⇔ `revoked_at IS NULL`.
- System-role relationships are never deleted: `deleteAgentRelationship` on one
  is turned into a revoke (sets `revoked_at`). `updateAgentRelationship` cannot
  change `subject`, `object`, `relationship` or `in_scope_of` of a system-role
  relationship.
- Partial unique index: one active relationship per
  `(subject_id, object_id, relationship_id)` where `revoked_at IS NULL`.

### 3.4 `zf_permission_log` (append-only)

| Column | Type | Notes |
|---|---|---|
| `id` | ULID PK | |
| `inserted_at` | utc datetime | |
| `actor_id` | ULID, nullable, FK → `vf_agent` | null for service principals |
| `service` | enum `gql \| admin_key \| import \| migration` | channel of the change |
| `action` | string | e.g. `relationship.grant`, `relationship.revoke`, `resource_control.set`, `person.create`, `person.delete` |
| `target_type` | string | `economic_resource`, `organization`, `agent_relationship`, `person` |
| `target_id` | ULID | |
| `subject_id` | ULID, nullable | agent receiving/losing the right |
| `role_key` | string, nullable | `system_key` of the role |
| `before`, `after` | jsonb, nullable | minimal relevant fields only, never keys, signatures or request bodies |
| `request_id` | string, nullable | from the GraphQL request |
| `reason` | text, nullable | required for `admin_key` actions |

- The module exposes only an insert function (`Zenflows.Authz.Log.multi_insert/3`).
- A PostgreSQL trigger raises on `UPDATE` and `DELETE` of this table.
- `actor_id`, `subject_id` and `target_id` are plain ULID columns **without**
  FK constraints: the log must outlive the agents and objects it mentions, and
  an `ON DELETE SET NULL` cascade would be an `UPDATE` rejected by the trigger.

## 4. Execution context

`Zenflows.Authz.ExecutionContext` — struct with `@enforce_keys
[:principal, :via, :request_id]`.

- `principal`: `%Zenflows.VF.Person{}` | `{:service, name :: atom(),
  allowed_actions :: MapSet.t()}` | `:anonymous`.
- `via`: `:gql | :admin_key | :import | :migration`.

Constructors (the only ways to build one):

| Constructor | Used by | Result |
|---|---|---|
| `from_resolution(res)` | resolvers of signed fields | Person from `res.context.req_user`; `:anonymous` if absent |
| `admin_key(res)` | resolvers of `only_admin?` fields, after `MW.Admin` passed | `{:service, :admin_key, actions}` |
| `service(name, actions)` | import (`SWPass.Domain`), migrations, jobs | `{:service, name, actions}` |

No constructor accepts GraphQL arguments. `request_id` is taken from a
`zenflows-request-id` header when present, otherwise generated.

**Auth disabled.** When `authenticate_calls?` is false, signed fields yield
`:anonymous`, and every protected action is denied, **unless**
`config :zenflows, Zenflows.Authz, allow_unchecked: true`, in which case
`:anonymous` is allowed everything (old behaviour for dev/test). The
application refuses to start when `allow_unchecked: true` and the release env
is `:prod`.

## 5. Policy

`Zenflows.Authz.Policy.authorize(ctx, action, facts) :: :ok | {:error,
:forbidden} | {:error, :unauthenticated}`

- Pure: no DB access. `facts` is a map built by the domain function
  (`%{control: %ResourceControl{} | nil, admin_of: MapSet.t(org_id),
  target: struct}`).
- Unknown action → `{:error, :forbidden}`.
- `:anonymous` → `{:error, :unauthenticated}` (or `:ok` under
  `allow_unchecked`).
- Service principals → `:ok` only if the action is in `allowed_actions`.

### 5.1 Action table

| Action | Allowed for a Person when |
|---|---|
| `resource.update`, `resource.delete` | `control.controller_id == person.id`, or `control.controller_id ∈ admin_of` |
| `organization.update`, `organization.delete` | `org.id ∈ admin_of` |
| `organization.create` | always (any authenticated Person) |
| `relationship.grant` (create with system role) | `object_id ∈ admin_of` |
| `relationship.revoke` (system role) | `object_id ∈ admin_of`, and not the last active `org.admin` of that org |
| `relationship.create/update/delete` (non-system role) | `subject_id == person.id`, or `subject_id ∈ admin_of` |
| `role.update`, `role.delete` | role has no `system_key`. Non-system roles stay editable by any authenticated Person, as today (shared vocabulary, no owner); known gap for a later slice |
| `person.update` | `target.id == person.id` |

A missing `control` row for a resource → deny.

Service principal action sets in this slice:

- `:admin_key` → `person.create`, `person.delete`, `sw_pass.import`,
  `organization.assign_admin`.
- `:import` → `resource.create`, `organization.create`,
  `relationship.grant`.
- `:migration` → `resource_control.set`.

## 6. Write path

Each protected domain function takes the context as first argument, e.g.
`EconomicResource.Domain.update(ctx, id, params)`. Inside one
`Repo.transaction` / `Ecto.Multi`:

1. load the target (`FOR UPDATE`);
2. load facts: `zf_resource_control` row `FOR UPDATE`; the caller's active
   `org.admin` relationships `FOR SHARE`;
3. `Policy.authorize/3` — on error, abort the multi;
4. existing changeset + write (VF validations unchanged);
5. if permissions changed: bump `epoch`, `Authz.Log.multi_insert`;
6. commit. A failed log insert rolls back the whole change.

Raw primitives (`multi_insert/update/delete` without context) become private
or are renamed `*_unchecked` and documented as internal; a test asserts that
no resolver or other domain module calls `*_unchecked` except the explicit
allowlist (migration backfill).

Functions changed in this slice:

- `EconomicResource.Domain`: `update`, `delete`, `multi_insert` (creation
  hook, §6.1), `multi_update`, `multi_delete`.
- `Organization.Domain`: `create`, `update`, `delete`.
- `AgentRelationship.Domain`: `create`, `update`, `delete`.
- `AgentRelationshipRole.Domain`: `update`, `delete`.
- `Person.Domain`: `create`, `update`, `delete`.
- `SWPass.Domain` import: receives `service(:import, …)`.

### 6.1 Controller on resource creation

All resource creation goes through `EconomicResource.Domain.multi_insert`
(event domain call sites for `resourceInventoriedAs` and
`toResourceInventoriedAs`, and the SWPass import). It inserts the control row
and its log entry in the same multi:

| Situation | `controller_id` | `source` |
|---|---|---|
| receiver is the ctx Person | ctx Person | `creation` |
| receiver is an org in `admin_of` | that org | `creation` |
| any other receiver | ctx Person (verified creator) | `creation`; declared receiver recorded in log `after` |
| service `:import` | declared target agent | `admin`; log `service: import` |

Event authorization itself (who may emit which event on which resource) is out
of scope (§7).

### 6.2 Organization creation and admin bootstrap

- `createOrganization` (signed) inserts the org, an `org.admin`
  `AgentRelationship` (subject = creator, object = org, `in_scope_of` = org)
  and a `relationship.grant` log row, atomically.
- New admin-key mutation
  `assignOrganizationAdmin(organizationId: ID!, personId: ID!, reason: String!)`
  for existing organizations, which start with **no admin** (existing
  relationships are not trusted). Logged with `service: admin_key` and the
  reason.

## 7. Scope boundaries

In scope: §3–§6, GraphQL error contract, backfill, tests.

Explicitly **not** in scope (later slices):

- Event authorization: `createEconomicEvent` can still change quantity,
  custody, accountability or containment of another agent's resource (F02).
  Next slice: `acting_for`, provider/receiver bound to the signer.
- Editor/viewer roles, project scope and inheritance, grants, invitations with
  acceptance, expiry, delegation.
- Two-step controller transfer.
- Nested read privacy (e.g. `primaryAccountable.email`), public projections
  (F05).
- DPP / feedback enforcement and the cross-service decision API (F03/F04).
- Request envelope v2 / anti-replay (F06).
- Durable audit of **denied** attempts (denials roll back their own
  transaction). This slice emits `[:zenflows, :authz, :deny]` telemetry and a
  `Logger.info` line with actor id, action, target id and request id only.

Related operational work, tracked separately: this slice adds
`assignOrganizationAdmin` to the `admin_key` surface. Handling of the admin
credential must be reviewed before deploying it.

## 8. GraphQL contract

- Denied → error with `extensions: %{code: "FORBIDDEN"}`, message
  `"forbidden"`; no controller or membership details.
- `:anonymous` without `allow_unchecked` → `extensions: %{code:
  "UNAUTHENTICATED"}`.
- Write on a non-existent ID by a caller → same `FORBIDDEN` (no ID probing via
  writes). Reads are unchanged in this slice.
- `MW.Errors` gains clauses for `{:error, :forbidden}` and
  `{:error, :unauthenticated}`.
- New query `resourceControl(resourceId: ID!): ResourceControl` returning
  `controller { id name }`, `source`, `epoch`; guest-readable, since resource
  primaryAccountable is already public. No log contents exposed.
- New admin mutation `assignOrganizationAdmin` (§6.2).
- Existing mutation inputs/outputs unchanged. Every mutation field declares
  one of:
  - `meta authz: <action>` — enforced by this slice;
  - `meta authz: :guest` — already `only_guest?`;
  - `meta authz: :signed_pending` — out of scope here (events, processes,
    specifications, …): any valid signer, exactly as today. These fields are
    listed in a test allowlist that later slices shrink; adding a new field
    to it requires editing the test.
- Deleting an Organization or Person that is a resource controller fails on
  the `zf_resource_control.controller_id` FK; this is intended (no orphaned
  control) and surfaces as the existing changeset/constraint error.

## 9. Configuration

```elixir
config :zenflows, Zenflows.Authz,
  enforce: true,          # default true; false only for staging gate
  allow_unchecked: false  # true only in dev/test with auth disabled
```

- `enforce: false` makes `Policy.authorize/3` return `:ok` while still running
  the write path, logging and deny telemetry (tagged `enforced: false`). It is
  a staging release gate, not a long-term mode.
- The application refuses to start in `:prod` if `enforce: false` or
  `allow_unchecked: true`.

## 10. Migrations and backfill

1. Create `zf_resource_control`, `zf_permission_log` (+ trigger), add
   `system_key`, `in_scope_of_id`, `revoked_at`, partial unique index.
2. Seed `org.admin`, `org.member` roles.
3. Backfill: for every `vf_economic_resource` without a control row, insert
   `controller_id = primary_accountable_id`, `source = backfill`, plus one log
   row (`service: migration`, `action: resource_control.set`). Decision taken
   by the team: existing `primaryAccountable` is trusted; provenance keeps it
   distinguishable.
4. No organization admin backfill. Existing organizations are administered
   only after `assignOrganizationAdmin`.
5. Down migrations drop the new structures; the log is lost on rollback, which
   is documented in the release notes.

## 11. Testing

All tests use the existing `EctoCase` / `AbsinCase` against PostgreSQL.

- **Policy unit tests**: table-driven over every action × principal kind
  (self, other person, active org admin, revoked admin, org member, service
  with/without action, anonymous, anonymous + `allow_unchecked`).
- **Domain tests (Alice/Bob)**: Bob is denied update/delete of Alice's
  resource; update/delete of an org where he is not admin; grant/revoke on
  that org; update of Alice's Person; update/delete of Alice's non-system
  relationships. Revoked admin denied. Last admin cannot be revoked. Org
  creator becomes admin. Resource created by Bob with Alice as receiver is
  controlled by Bob.
- **API tests with auth enabled**: new `AbsinCase` helper signing requests as
  a fixture Person; covers aliases and multiple root fields in one document,
  missing headers, wrong signature, and `FORBIDDEN`/`UNAUTHENTICATED` codes.
  Existing tests keep running with auth disabled + `allow_unchecked: true` and
  pass a context where they call domain functions directly.
- **Log tests**: each permission change writes exactly one row with expected
  fields; failed log insert rolls back the change; trigger rejects
  `UPDATE`/`DELETE`; no key/signature material in `before`/`after`.
- **Coverage guard**: test walks the Absinthe schema and fails if a mutation
  field lacks `meta authz`, declares an action unknown to `Policy`, or uses
  `:signed_pending` without being in the allowlist.
- **Unchecked-primitive guard**: test fails if `*_unchecked` functions are
  referenced outside the allowlist.
- **Creation guard**: every resource-creating event path produces a control
  row.
- **Concurrency**: update by an admin racing a revoke of that admin, two
  sandboxed connections; outcome is serialized (either update-then-revoke or
  revoke-then-deny), never update-after-revoke.
- **Boot guard**: `:prod` with permissive config refuses to start.

## 12. Acceptance

- All tests in §11 pass on a clean database.
- Alice/Bob negatives reproducible from a clean checkout.
- Every mutation field has `meta authz`.
- Release notes state: "CRUD enforced; events pending", list the new error
  codes, `resourceControl`, `assignOrganizationAdmin`, and the need to assign
  admins to existing organizations.

## 13. Follow-ups enabled by this slice

- Slice 2: event authorization (`acting_for`, provider/receiver binding).
- Slice 3: `org.member` and editor/viewer roles, `in_scope_of` project scopes,
  invitations.
- GUI: handle `FORBIDDEN`, use `resourceControl` to hide edit affordances (UX
  only).
- Decision API for DPP/feedback built on `Policy`.
