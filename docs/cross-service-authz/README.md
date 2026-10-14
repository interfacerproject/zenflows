# Cross-service authorization — shared test vectors

These vectors are the conformance suite for the cross-service authorization
contract (`../cross-service-authz-contract.md`). They are the source
of truth: both the Go PEP library (DPP, wallet, inbox, feedback) and the
Elixir PDP counterpart in Zenflows consume the same files, so "uniform" is a
property that is tested, not asserted.

## Files

- `authn.json` — the authentication floor (§2 of the contract). Executable
  against a PEP alone, with no PDP. These are the first-slice (P0) cases.
- `contract.json` — the PDP request/response contract (§3, §4). These need the
  PDP; until it exists a runner MUST report them as **pending**, never green.

## Vector schema

Each file is `{ "layer": "...", "vectors": [ ... ] }`. Each vector:

```jsonc
{
  "name": "authn.missing_signature",       // unique, dotted
  "layer": "authn",                          // "authn" | "contract"
  "doc": "...",                              // one line, why this case exists
  "input": { ... },                          // see per-layer shape below
  "expect": { ... }                          // see per-layer shape below
}
```

### `layer: "authn"` input / expect

`input` models a request arriving at a PEP:

```jsonc
"input": {
  "route":   "DELETE /dpp/:id",             // the registered route
  "path":    { "id": "01ABC..." },          // resolved path params
  "headers": { "did-pk": "...", "did-sign": "...", "x-user-id": "..." },
  "signed_payload": { ... } | null,          // the §2 envelope the client signed
  "did_resolves": true,                       // stub: does VerifyDid succeed
  "signature_valid": true                     // stub: does IsAuth succeed
}
```

`did_resolves` and `signature_valid` are **stubs**: a vector pins PEP policy,
not Zenroom/network behaviour. A conformance runner wires them to a fake
`VerifyDid`/`IsAuth`. `expect`:

```jsonc
"expect": {
  "outcome":   "accept" | "reject",
  "principal": { "did": "...", "pk": "..." } | null,  // when accept
  "reason":    "missing_signature" | "did_unresolved"
             | "bad_signature" | "object_id_mismatch"
             | "stale" | "replayed" | "ok"
}
```

### `layer: "contract"` input / expect

`input` is a PDP request as in contract §4.1; `expect` is the decision the PDP
must return, plus any obligation the PEP must then enforce. A runner that has
no PDP yet MUST mark these **pending**.

## Runner contract

A conforming runner:

1. Loads a layer file, iterates vectors.
2. For `authn`: feeds `input` to the PEP with stubbed `VerifyDid`/`IsAuth`
   driven by `did_resolves`/`signature_valid`, asserts `outcome`, `principal`,
   `reason`.
3. For `contract`: if no PDP is wired, prints `PENDING <name>` and counts it as
   neither pass nor fail (but a non-empty pending set fails a `--strict` run, so
   "pending" can never masquerade as "done").
4. Exits non-zero on any mismatch.

The Go and Elixir runners live with their implementations; only the vectors
are shared here.
