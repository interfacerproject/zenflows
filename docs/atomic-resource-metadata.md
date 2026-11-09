# Atomic administrative resource metadata patches

Workstream: interfacerproject/zenflows#74 (non-closing reference).
Depends on the complete #71/#72/#73 authorization stack. This is additive;
no authorization bypass, new organization policy, migration, SDK publication
or deployment is introduced.

## Contract

`economicResource { metadata metadataHash }` returns an opaque SHA-256 content
fingerprint. `patchEconomicResourceMetadata(resourceId: ID!, fields: JSONObject!,
expectedMetadataHash: String)` returns `economicResource { id metadata metadataHash }`.

Like other JSONObject **inputs**, fields are JSON object documents encoded as
strings. Output metadata remains an object. Example variables:

```json
{"resourceId": "RESOURCE_ID", "fields": "{\"relations\":[]}"}
```

This shallow operation replaces only supplied top-level fields. Unknown keys
are preserved; arrays and nested objects replace the whole field; null is stored,
not deletion. Empty/unchanged patches still authorize and check preconditions,
but create neither a write nor an audit entry.

With an expected fingerprint, differing current content returns a safe
`extensions.code = CONFLICT`. Omitting it opts into last-committer-wins for
overlapping fields; unrelated concurrent patches preserve one another.
This is **content CAS**, not a monotonically increasing revision: object key
order is ignored, array order retained, and content changing then changing back
(ABA) has the same token. It does not make legacy full replacements safe to
merge, or automatically reconcile an old UI draft.

## Transaction and policy

The existing `resource.update` policy runs inside the transaction, using
`Facts.for_resource` to lock the resource/control and relevant active admin
relationship rows. Only after authorization are current content, precondition
and patch examined. Revoked control/admin does not authorize a waiting write.
Accountable/contributor fields are not control grants.

Resource changes and an append-only administrative `resource.metadata.patch`
entry commit together. The existing `zf_permission_log` trail is extended for
this explicit action: actor/service/request come from ExecutionContext; before
and after contain metadata content fingerprints and changed field names, not
raw metadata. Fingerprints are audit evidence, **not encryption or authorization**.
Any audit failure rolls back the resource edit. This is not an economic event
or a full reconstructible metadata history.

No process, accept/modify event, quantity/custody/accountable/control change or
previous-event link is manufactured. Existing economic event metadata workflows
and replacement semantics remain unchanged and can still partially commit.

## Client rollout / verification

Use the additive SDK `resources.patchMetadata(id, fields, {expectedMetadataHash})`;
keep its separate PR dependency on SDK #2 and normal release/update sequence.
GUI field editors should stop resending a full map and should not fall back to
legacy operations when this endpoint/export is absent. No automatic retry on
conflict, network error or malformed success: uncertain delivery is not rollback.

Regressions use independent PostgreSQL connections (not a shared sandbox
connection) for parked/stressed patch races, CAS and control-change rechecks.
Rollback is checked by making audit validation fail after the resource edit.
Real signed SDK/WASM/API and separate React/browser evidence are recorded in
the linked PRs. Known whole-suite failures are not excluded or declared fixed.
