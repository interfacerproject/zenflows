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

# Authorization foundation — release notes

**Status: CRUD, events, processes, intents and proposals enforced;
groups, plans, agreements and catalogue types pending.**  Do not
describe resources or processes/intents/proposals as generally
protected: process groups, plans, scenarios, scenario definitions,
agreements, catalogue types (resource specifications, process
specifications, units, spatial things, recipes, role behaviors, product
batches) and commitments are still unauthorized.

## Behaviour changes

- `updateEconomicResource`, `deleteEconomicResource`: resource controller, or
  an admin of the controlling organization.
- `createOrganization`: the signer becomes the organization's first admin.
  `updateOrganization`, `deleteOrganization`: organization admins only.
- `createAgentRelationship` with a system role (`org.admin`, `org.member`)
  is a grant: organization admins only.  Deleting such a relationship
  revokes it (`revokedAt`), it is never removed.  The last admin cannot be
  revoked.  Other relationships: their subject (or an admin of the subject
  organization).
- `updatePerson`: self only.
- System roles (`systemKey` not null) cannot be edited or deleted.
- Organizations/persons that control resources or take part in
  relationships cannot be hard-deleted.  Because system-role relationships
  are revoked, never deleted, this means **organizations created after this
  upgrade, and persons who created organizations or resources, can no longer
  be hard-deleted at all**.  An archive path is planned for a later slice.
- Backfilled resources whose primaryAccountable is an organization are
  controlled by that organization: nobody can edit or delete them until the
  organization gets an admin (`assignOrganizationAdmin`).
- Anonymous callers (signature checks off, `GQL_AUTH_CALLS=false`) must pass
  `resource.create` authorization before an event can create a resource.
  With `AUTHZ_ALLOW_UNCHECKED=false` such calls are rejected
  (`UNAUTHENTICATED`); only in unchecked mode (dev/test) does the
  primaryAccountable become controller.

## Errors

- `extensions.code: "FORBIDDEN"` (message `forbidden`) on denial, also for
  writes on IDs that do not exist.
- `extensions.code: "UNAUTHENTICATED"` for unsigned writes when signature
  checks are disabled and `AUTHZ_ALLOW_UNCHECKED=false`.
- When several non-null root fields in the same GraphQL document fail, each
  is denied individually, but Absinthe's null propagation reports them as a
  single error in the response.

## New API

- `resourceControl(resourceId: ID!) { controller { id } source epoch }`
- `assignOrganizationAdmin(organizationId, personId, reason)` — admin key
  only, always logged.
- `AgentRelationship.inScopeOf`, `AgentRelationship.revokedAt`,
  `AgentRelationshipRole.systemKey`.
- Optional request header `zenflows-request-id` (`[A-Za-z0-9_-]{1,64}`),
  stored with permission log entries.

## Operations

- Migrations add `zf_resource_control` and the append-only
  `zf_permission_log`, seed the system roles, and backfill a controller for
  every existing resource from its `primaryAccountable` (`source: backfill`).
- **Existing organizations have no admin after the upgrade.**  Assign admins
  with `assignOrganizationAdmin` before users need to edit them.
- `assignOrganizationAdmin` widens the admin-key surface: review admin key
  handling before deploying.
- Rolling back the migrations drops the permission log, and also deletes
  every system-role relationship (all organization admin/member grants,
  including revoked ones) together with the system roles.
- The append-only trigger on `zf_permission_log` blocks `UPDATE` and
  `DELETE`, but not `TRUNCATE`.  In production, restrict table privileges
  (no `TRUNCATE` for the application role) to keep the log append-only.

## Event authorization (slice 2)

- `createEconomicEvent`: the signer must act for the provider or the
  receiver (themselves, or an organization they administer), and must
  control every resource the event changes (including a container's
  contents).  `cite` and `use` may reference any resource.  `combine` and
  `separate` are rejected.
- Resources created by `transfer`, `transferAllRights`, `transferCustody`
  and `move` are controlled by the receiver.
- Claims: resources controlled by an agent in `AUTHZ_CLAIMABLE_AGENTS` may
  be transferred by anyone into a new resource of their own; each claim is
  logged as `resource.claim`.  **Set `AUTHZ_CLAIMABLE_AGENTS` to the LOSH
  agent id before deploying, or the GUI claim page stops working.**
- `updateEconomicEvent` works again (the resolver argument was broken) and
  is limited to the event's provider or receiver.
- Transferring into an existing destination (`toResourceInventoriedAs` set)
  requires controlling that destination resource too, not just the source.
- Resources whose controller is an organization — including ones backfilled
  from `primaryAccountable` — block events, the same way they already block
  CRUD, until that organization has an admin.
- `cite` and `use` update the cited/used resource's lineage pointer
  (`previousEventId`), and anyone may call them on any resource: a
  stranger's `cite`/`use` event can therefore appear in a resource's trace.
- The signer only has to act for one side of an event; they may name any
  agent on the other side.  For example, signing as Bob, Bob may record a
  `work` event with provider Alice and receiver Bob — Alice's participation
  is not checked.
- Still unauthorized at the end of this slice: processes, process
  groups, intents, proposals, proposed intents, satisfactions,
  agreements; attaching an event to another agent's process is still
  possible.  Slice 3 (below) closes the processes/intents/proposals
  gap.

### Deploying slices 1 and 2

Slice 1 (PR #71) alone gives the resource created by a transfer-type event
(`transfer`, `transferAllRights`, `transferCustody`, `move`) to the
**provider** (the creator); slice 2 gives it to the **receiver**.  Deploy
both slices together.

If slice 1 ran alone in some environment before slice 2 was deployed, run
this fix-up once, after deploying slice 2, best as a migration (so each
changed row is logged to `zf_permission_log` as `resource_control.set`,
service `migration`, the way `Zenflows.Authz.Backfill` already does for the
initial backfill):

```sql
UPDATE zf_resource_control AS rc
SET controller_id = r.primary_accountable_id,
    epoch = rc.epoch + 1
FROM vf_economic_resource AS r
JOIN vf_economic_event AS e ON e.id = r.previous_event_id
WHERE rc.resource_id = r.id
  AND rc.source = 'creation'
  AND e.action_id IN ('transfer', 'transferAllRights', 'transferCustody', 'move')
  AND rc.controller_id <> e.receiver_id;
```

(`primary_accountable_id` on these resources is always the event's
`receiver_id` — the event handlers set it that way — so the two are
interchangeable here; the statement uses the join only to find the right
rows.)

## Processes, intents and proposals (slice 3)

- `createProcess`, `createProposal`, `createIntent`: the signer becomes
  the controller (`source: creation`); there is no organization case
  (these objects carry no agent field).  Service principals (`:import`,
  `:migration`) create without a control row, as for resources;
  anonymous calls follow slice 1 (`UNAUTHENTICATED` unless
  `AUTHZ_ALLOW_UNCHECKED=true`, in which case they too create without a
  control row).
- `updateProcess`/`deleteProcess`, `updateProposal`/`deleteProposal`,
  `deleteIntent`: the controller only.  Other agents' processes,
  proposals and intents are now read-only through these mutations.
- `createIntent`: if `inputOf`/`outputOf` is set, the signer must
  control that process — the intent may then name only the other party
  (the signer need not be its provider or receiver); otherwise the
  signer must act for the provider or the receiver.
- `updateIntent`: the controller, or an agent acting for its provider or
  receiver, or — only when the update sets nothing but `finished: true`
  — an agent acting for a provider or receiver of any intent published
  in the same proposal (this keeps the SDK's `rejectProposal`, which
  finishes all three intents of a contribution proposal signed by the
  owner, working without letting anyone change anything else on those
  intents).  Changing provider, receiver, `inputOf` or `outputOf` is
  additionally checked against the `createIntent` rule for the
  resulting intent; changing `inputOf`/`outputOf` away from a process
  (including to `null`) additionally requires controlling that *old*
  process, so a named party cannot use the process-less fallback to
  unilaterally detach an intent from a process someone else controls.
- `proposeIntent`: the signer must control the proposal **and** either
  control the intent or act for its provider or receiver.
  `deleteProposedIntent`: the signer must control the proposal.
- `createSatisfaction`: requires `satisfiedByEvent` (`satisfiedByCommitment`
  is always denied — it is also not exposed as an input field);
  the signer must act for the satisfying event's provider or receiver,
  and that event must share a provider or receiver with the intent it
  satisfies.  `updateSatisfaction`/`deleteSatisfaction`: the signer
  acting for the provider or receiver of the satisfying event; changing
  which event (or commitment) or which intent a satisfaction points to
  is additionally checked against the `createSatisfaction` rule for the
  resulting pair (an intent that doesn't exist is denied).
- Intents attach only to processes the signer controls: an
  `inputOf`/`outputOf` reference on `createIntent`/`updateIntent`
  requires controlling that process.
- Events attach (`inputOf`/`outputOf` on `createEconomicEvent`) to a
  process the signer controls **or is invited to**: the process holds
  at least one unfinished intent (`finished: false`, `inputOf` or
  `outputOf` that process) whose provider or receiver the signer acts
  for (self, or an organization the signer is an active admin of).
  Otherwise `FORBIDDEN` (telemetry rule `:process`).  This keeps
  interfacer-gui's proposal acceptance working: its `ACCEPT_PROPOSAL`
  attaches the owner's cite/accept/modify events to the *proposer's*
  process, whose unfinished accept/modify intents name the owner.
  Finishing those intents (e.g. `rejectProposal`) ends the invitation.
- **Processes, proposals and intents created before this upgrade have
  no control row: deny-all for every controller action (update, delete,
  attaching an intent; attaching an event unless invited, see above)
  until `assignObjectControl` assigns one.**  The party-based rules
  above (a named party updating an intent, satisfactions) and the
  event invitation still apply to legacy objects.  So an old
  contribution proposal can still be rejected (the owner finishes the
  intents), and can still be accepted through the GUI flow
  (`ACCEPT_PROPOSAL` with the proposer's legacy process, then
  `SATISFY_INTENTS`) as long as that process holds the unfinished
  accept/modify intents naming the owner.  Once those intents are
  finished, events can no longer attach to the legacy process until it
  gets a controller.
- New guest query: `objectControl(targetType: String!, targetId: ID!)
  { controller { id } source epoch }`.
- New admin-key mutation: `assignObjectControl(targetType: String!,
  targetId: ID!, personId: ID!, reason: String!)` — creates or replaces
  a process/proposal/intent's control row, always logged with the
  reason.  The target must exist (`target not found` otherwise).
- Still unauthorized: process groups, plans, scenarios, scenario
  definitions, agreements, catalogue types (resource specifications,
  process specifications, units, spatial things, recipes, role
  behaviors, product batches) and commitments.

## Known limitations

- The last-admin protection is enforced by the policy only, so it does not
  apply when `AUTHZ_ENFORCE=false` (staging gate).
- Deleting an economic resource that has event history fails on a
  pre-existing foreign key (independent of authorization).
- Admin-key GraphQL tests could not be exercised in the development
  environment used here (Restroom `byte_equal?` service mismatch);
  domain-level tests cover the logic.
- Containment discovery for the container rule runs before the resource
  locks are taken: a content attached to a changed resource between
  discovery and lock would be missed.  No API sets containment today, so
  this is a documented limitation, to be revisited with `combine`/
  `separate`.
- The SWPass import writes events and resources directly, without an
  `event.create` decision or deny telemetry.  It runs only behind the
  admin key, as the `:import` service, which is otherwise allowed to
  create events; this is a documented exception, not a gap reachable by
  ordinary callers.
- A missing event on `updateEconomicEvent` is reported to operators with
  deny telemetry rule `:agent` (the stored event is required to tell
  which agent rule failed, so the generic fallback rule is used).
- An event and a concurrent `deleteOrganization` of an agent it references
  can deadlock on each other's foreign-key locks; PostgreSQL aborts one
  side, so both outcomes are errors (the delete is blocked by foreign keys
  anyway, regardless of which side wins).
- `updateSatisfaction` cannot change only the note or quantities: the
  existing changeset requires the event/commitment reference to change
  (pre-existing, unrelated to authorization).
- Satisfactions backed by a commitment can't be updated or deleted by
  persons (commitments aren't exposed in the API).
- Telemetry for denied process/proposal/intent/proposed-intent/
  satisfaction actions carries no specific rule (only events report
  `:process`); these denials are reported with rule `nil`, as in
  slice 1.
- A delete of a process/proposal/intent racing a concurrent child
  insert (an event or intent attaching to it, a satisfaction referencing
  it) can still deadlock on each other's foreign-key locks; PostgreSQL
  aborts one side, so both outcomes are errors.
