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

**Status: CRUD enforced; events pending.**  `createEconomicEvent` can still
change quantity, custody, accountability or containment of another agent's
resource; that is the next slice.  Do not describe resources as generally
protected.

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
  relationships cannot be hard-deleted.
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
- Rolling back the migrations drops the permission log.

## Known limitations

- The last-admin protection is enforced by the policy only, so it does not
  apply when `AUTHZ_ENFORCE=false` (staging gate).
- Mutual revokes across two different organizations by the same two admins
  can still deadlock; PostgreSQL aborts one transaction, which surfaces as
  an error.
- Deleting an economic resource that has event history fails on a
  pre-existing foreign key (independent of authorization).
- Admin-key GraphQL tests could not be exercised in the development
  environment used here (Restroom `byte_equal?` service mismatch);
  domain-level tests cover the logic.
