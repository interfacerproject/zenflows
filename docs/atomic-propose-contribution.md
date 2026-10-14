# Atomic contribution proposals

Workstream: interfacerproject/zenflows#74 (non-closing reference).
Stacked on #76 (atomic acceptance). Additive: existing mutations, rules and
documents are unchanged.

## Problem

The GUI's `pages/project/[id]/propose_contribution.tsx` (and the SDK's
`proposeContribution`) create a contribution proposal in four requests:
process, proposal, three intents, three proposed-intent links. A failure in
between leaves orphans; unfinished intents naming the owner keep inviting
the owner into the proposer's process (slice-3 §3.2) even though no proposal
references them. A retry creates a second proposal. The GUI also names the
origin's `primaryAccountable` as owner: when that is not the controller,
neither the named party (no control) nor the controller (not named) can
accept the proposal.

## Contract

```graphql
proposeContribution(resourceForkedId: ID!, resourceOriginId: ID!,
                    name: String, note: String): ProposeContributionResponse!
type ProposeContributionResponse {
  proposal: Proposal!
  process: Process!
  citeIntent: Intent!
  acceptIntent: Intent!
  modifyIntent: Intent!
  created: Boolean!
}
```

The server decides the parties:

- **proposer** = the signer;
- **owner** = the origin's controller (a Person, or an Organization — its
  active admins can then accept through the existing event rules);
- the signer must control the fork (`resource.update` on it): a contribution
  is your own work, and accepting it appends the fork to the origin's
  relations.

One transaction writes, through the existing domain functions and policy
(`process.create`, `intent.create`, `proposal.create`,
`proposed_intent.create`): the proposer's process, `cite` (provider:
proposer, fork, `inputOf`), `accept` (receiver: owner, origin, `inputOf`)
and `modify` (receiver: owner, origin, `outputOf`) intents, the proposal
and three primary links. Intent quantities are each resource's current
on-hand quantity and unit, which is what acceptance needs.

### Idempotency

If the signer already has a **pending** proposal (as `proposalStatus`
computes it) for the same fork → origin, with the same owner, it is
returned with `created: false` and nothing is written (`name` and `note`
are not compared). After a rejection or acceptance a new proposal can be
made.

### Errors

| Case | Result |
| --- | --- |
| fork = origin, unknown resource, origin without controller | `BAD_USER_INPUT` |
| signer does not control the fork | `FORBIDDEN`, nothing written |
| any write denied or invalid after the first | everything rolled back |

## Locks

Fork and origin resource rows `FOR UPDATE`, ascending id, first (the same
order as `acceptContribution`); this serializes concurrent proposals for the
same pair, so the idempotency check sees a committed earlier one. Then the
fork's control row (`resource.update` facts) and the origin's control row
`FOR SHARE`. The domain functions take their usual locks afterwards.

## Not changed

The old multi-request sequences keep working and keep their partial-commit
risk. Existing orphan intents are not cleaned up. Acceptance by an
Organization owner also requires the origin's custodian to be that
Organization (the existing `accept` event custody check).
