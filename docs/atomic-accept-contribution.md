# Atomic contribution acceptance

Workstream: interfacerproject/zenflows#74 (non-closing reference).
Stacked on #75 (atomic resource metadata), which depends on #71/#72/#73.
Additive: existing mutations, rules and documents are unchanged.

## Problem

The SDK's `acceptProposal` and the GUI's `pages/proposal/[id].tsx` accept a
contribution in two non-transactional requests: three events
(`cite`/`accept`/`modify`), then three satisfactions. If the second request
fails, the events stay committed and the proposal stays `PENDING`; retrying
creates the events again (the SDK opens a new process each time, so the
one-`accept`-per-process check does not stop it). The GUI's `modify` event
also carries a whole metadata map computed in the browser, replacing
whatever the origin resource holds at commit time.

## Contract

```graphql
acceptContribution(proposalId: ID!): AcceptContributionResponse!
type AcceptContributionResponse {
  proposal: Proposal!
  citeEvent: EconomicEvent!
  acceptEvent: EconomicEvent!
  modifyEvent: EconomicEvent!
}
```

A *contribution proposal* has exactly three primary intents, as
`proposeContribution` creates them: `cite` (provider: proposer) on the fork,
`accept` (`inputOf` P, receiver: owner) and `modify` (`outputOf` P,
receiver: owner) on the origin, all in the proposer's process P. Anything
else is `BAD_USER_INPUT` ("not a contribution proposal").

One transaction, on success:

- `cite` event: proposer → owner, fork, `inputOf` P;
- `accept` event: owner → owner, origin, `inputOf` P;
- `modify` event: owner → owner, origin, `outputOf` P, with
  `resourceMetadata` = the origin's **current** metadata with the fork id
  appended to `relations` (no duplicate). Other keys are preserved;
- one satisfaction per intent, linking it to its event.

Quantities and units come from the intents; timestamps are server time.

### Idempotency and states

After the locks below are held, the proposal is re-read:

| State | Result |
| --- | --- |
| all intents unfinished, no satisfactions | accept as above |
| every intent satisfied by exactly one event | success, returns the existing events; nothing is written |
| anything else (rejected, partially satisfied, finished) | `CONFLICT` ("proposal is not pending") |

So a retry after an uncertain response is safe, and two concurrent accepts
of the same proposal produce one set of events.

## Authorization

No new rule. Every write goes through the existing policy, inside the same
transaction: `event.create` (slice 2: the signer controls the changed origin
resource and acts for the owner; the events attach to P by the slice-3
invited-party rule, §3.2) and `satisfaction.create` (§3). A signer who is
not the owner's agent, or does not control the origin, gets `FORBIDDEN` and
nothing is written. The mutation is tagged `meta authz: "event.create"`.

## Locks

Origin and fork resource rows `FOR UPDATE`, ascending id, first; then the
three intent rows (with their proposed-intent link rows) `FOR SHARE`,
ascending id; the proposal's shape is re-checked on the locked rows. This follows the slice-3 order
(resource rows → control rows → intent rows → admin rows). Concurrent
accepts of one proposal serialize on the origin row. A concurrent
`rejectProposal` (`updateIntent` takes the intent `FOR NO KEY UPDATE`)
either commits first (accept then sees finished intents → `CONFLICT`) or
waits and finishes the already-satisfied intents (status stays `ACCEPTED`,
the existing status query is unchanged). A concurrent metadata patch on the
origin waits for the row lock, so neither side loses fields.

## Verification

`test/authz/accept_contribution.test.exs` (12, GraphQL and domain) and
`test/authz/accept_contribution_concurrency.test.exs` (5, separate
PostgreSQL connections outside the sandbox): one-call accept, retry
idempotency, Carol/proposer/lost-control denials with nothing written,
rejected and half-accepted proposals, non-contribution input, rollback after
the first event, concurrent accept/accept, reject/accept both ways and
metadata patch/accept.

## Not changed

`createEconomicEvent`/`createSatisfaction` and the old SDK/GUI sequences keep
working (and keep their partial-commit risk). Legacy proposals already left
half-accepted are reported as `CONFLICT`, never repaired automatically. No
audit row is added: the events and satisfactions are the economic record.
