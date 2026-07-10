# Deployment records

The [`suggested operational runbook`](../docs/runbook.md) describes a proposed division of responsibilities for module teams, ProSec, and Governance Facilitators. The schemas, manifests, and lifecycle rules in this directory remain authoritative for recorded deployment status.

Deployment records are split by chain ID and architecture generation.

`1/legacy-v1.json` is a signed, versioned Mainnet snapshot copied from the V1 deployment section of `README.md` at the signed `v1-final` tag. It records historical operational artifacts; inclusion and snapshot status do not imply that an address is still authoritative.

`1/v1-migration.json` is the current migration overlay for every address in that immutable snapshot. Its shape is documented by [`v1-migration.schema.json`](./v1-migration.schema.json), and its identity, status, ownership, evidence, counts, and V2 replacement bindings are enforced by [`emergency-spells`](../cli/emergency-spells). Run:

```sh
cli/emergency-spells validate-migration \
  --legacy deployments/1/legacy-v1.json \
  --v2 deployments/1/v2.json \
  --mig deployments/1/v1-migration.json
```

The current overlay uses these migration states:

- `waiting-for-reviewed-v2-replacement` retains documented V1 standby coverage while a V2 replacement is pending;
- `deprecated-v1` preserves the exclusion recorded in the signed V1 snapshot;
- `revoked-v1` withdraws a historically active V1 artifact from incident use before a replacement exists and requires a revocation reason;
- `superseded-by-v2` requires an explicit `incident-ready` replacement, an allowed action-family mapping, and an approved coverage-equivalence review;
- `retained-v1-exception` requires a documented retention rationale.

The 49 entries classified active in the signed V1 snapshot initially use the waiting status. The 25 deprecated snapshot entries use `deprecated-v1`. Ownership is explicitly `unassigned` because the governance process has not resolved publication and revocation ownership. Do not infer an owner or mutate the historical snapshot to fill that gap. A migration status documents the canonical repository classification; it does not prove current Chief authorization, on-chain permissions, or incident readiness.

`<chain-id>/v2.json` is the V2 implementation and review manifest. Its JSON shape is documented by [`v2.schema.json`](./v2.schema.json), and the canonical cross-field rules are enforced by [`emergency-spells`](../cli/emergency-spells). In particular:

- only leaf records can be batch-eligible;
- batch-eligible leaves require approved direct-use and batch-use reviews;
- batch preflight accepts only leaves whose operational status is `incident-ready`;
- globals, batches, and infrastructure are direct-use only;
- addresses are unique within a manifest;
- batch records include their ordered leaves, factory, deployment mode, configuration hash, getter readbacks, event check, and atomic simulation attestation;
- every spell artifact identifies its declared contract under `src/` and records the shared `action()` and `pause()` interface readbacks;
- adding a new concrete spell does not require changing the validator.

Every V2 record contains the chain, contract category, address, runtime codehash, exact source commit, deployment transaction and block, constructor arguments, immutable getter readbacks, subjects and parameters, review status, and operational status. Subject and parameter keys are getter signatures, and their machine values must exactly match the corresponding immutable readbacks; free-form labels are not authoritative. Unknown historical V1 provenance stays explicit in the legacy record; it must not be inferred into a V2 record.

A V2 leaf or batch must not be treated as reviewed or incident-ready merely because it appears in the manifest. Use the deployment validators documented in [`script/README.md`](../script/README.md), and retain the referenced review and simulation evidence.

## Deployment publication workflow

Deployment JSON is drafted by the CLI and incorporated into the manifest through review. The CLI does not update `v2.json` directly.

1. Deploy the concrete spell or factory from the reviewed source commit. For a batch, preflight the exact factory, deployment mode, label, and ordered leaves before broadcasting.
2. Wait for the deployment transaction to succeed and retain its transaction hash.
3. Run `draft-deployment` for a direct deployment or `draft-batch` for a factory-created batch. Redirect standard output to a temporary JSON file.
4. Review the generated address, transaction, block, constructor arguments, runtime codehash, subjects, parameters, immutable readbacks, and, for batches, factory event and getter readbacks against the deployment evidence.
5. Copy the drafted record into the `records` array of the applicable `<chain-id>/v2.json`. Do not replace or reorder unrelated records.
6. Complete the review fields and lifecycle state from approved evidence. For a batch, also replace every placeholder in `atomicSimulation` with the reviewed simulation reference, chain state, Chief address, and verification results.
7. Run `validate-manifest` and resolve every schema or cross-record error. A raw draft is expected to fail because its review and simulation evidence is intentionally incomplete.
8. Run `verify-deployment` for a direct deployment or `verify-batch` for a batch. Verification recompiles the recorded artifact, checks the deployment transaction and receipt, and compares live code and getter readbacks.
9. Commit the manifest and evidence references in a signed commit. Before incident use, fetch and verify the latest canonical manifest commit and record that commit in the incident log.

The batch draft takes `sourceCommit` from the published factory record because the factory's compiled creation code performed the deployment. The factory and selected leaves must already exist in the input manifest; the new batch record is added only after the draft has been reviewed.

## Status and revocation

A V1 migration change must preserve the exact identity copied from `legacy-v1.json`, update the aggregate counts, include evidence, and arrive in a signed commit. The migration validator first validates the complete V2 manifest before trusting a replacement. A superseded record must reference an `incident-ready` V2 address in the allowed action family and include an approved review bound to both addresses, the legacy name, kind, subject and parameter, the replacement contract, its manifest subjects and parameters, and a description of intended coverage. Batch replacements additionally must contain only leaves in the corresponding action family. A retained exception must explain why V1 remains the safer operational path. A revoked record must explain why formerly active V1 coverage was withdrawn. The immutable legacy snapshot itself is never rewritten to represent current status.

The intended lifecycle is `deployed` → `reviewed` → `incident-ready`. `revoked` removes an artifact from incident use without erasing its history; `superseded` identifies a historical record replaced by another published artifact. Every transition requires a signed repository commit and evidence in the applicable review fields. An `incident-ready` record requires approved direct-use review. Batch-eligible leaves additionally require approved batch-use review. Revoking or superseding a leaf requires every incident-ready batch that contains it to be revoked or superseded in the same manifest update. A ready batch likewise requires its recorded factory to remain incident-ready. Revoked batches remain valid historical records and can still be revalidated against their retained leaf and factory provenance.

The governance process has not yet assigned a permanent owner for publication and revocation. Until it does, this remains an explicit manual control: the operator selecting an emergency artifact must identify the canonical repository ref with the Governance Facilitator, fetch it, verify its commit signature, confirm that the worktree and submodules are clean, and record that manifest commit in the incident log. A stale local manifest is never sufficient evidence after canonical status may have changed.

Deployment validation uses this repository's build inputs. Git verifies that the repository and submodules are clean, that the recorded `sourceCommit` is signed, and that the current checkout has no differences from that commit in `src/`, `foundry.toml`, `.gitmodules`, `lib/`, or `remappings.txt`. Foundry then forces a fresh compilation before comparing deployment bytecode. This permits later documentation and manifest-only commits while preserving exact source and dependency equivalence.

The structured atomic-simulation object is an attestation, not an on-chain proof. Tooling binds it to the batch address, configuration hash, chain, and block. Reviewers remain responsible for following its reference and confirming that the trace demonstrates Chief hat authorization, downstream calls from the batch address, exact leaf behavior, and atomic rollback on failure.
