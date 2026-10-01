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

**Status: CRUD and events enforced; processes, intents and proposals
pending.**  Do not describe resources as generally protected: processes,
process groups, intents, proposals, proposed intents, satisfactions and
agreements are still unauthorized.

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
- Still unauthorized: processes, process groups, intents, proposals,
  proposed intents, satisfactions, agreements; attaching an event to
  another agent's process is still possible.

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
