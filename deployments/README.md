# Deployment records

Deployment records are split by chain ID and architecture generation.

`1/legacy-v1.json` is a signed, versioned Mainnet snapshot copied from the V1
deployment section of `README.md` at the signed `v1-final` tag. It records
historical operational artifacts; inclusion and snapshot status do not imply
that an address is still authoritative.

`<chain-id>/v2.json` is the V2 implementation and review manifest. Its JSON
shape is documented by [`v2.schema.json`](./v2.schema.json), and the canonical
cross-field and contract allowlist rules are enforced by
[`validate-v2-manifest.sh`](../scripts/validate-v2-manifest.sh). In particular:

- only leaf records can be batch-eligible;
- batch-eligible leaves require approved direct-use and batch-use reviews;
- batch preflight accepts only leaves whose operational status is
  `incident-ready`;
- globals, batches, and infrastructure are direct-use only;
- addresses are unique within a manifest;
- batch records include their ordered leaves, factory, deployment mode,
  configuration hash, getter readbacks, event check, and atomic simulation
  attestation;
- every current V2 contract name resolves to one exact artifact, category, and
  complete set of public immutable readbacks.

Every V2 record contains the chain, contract category, address, runtime
codehash, exact source commit, deployment transaction and block, constructor
arguments, immutable getter readbacks, subjects and parameters, review status,
and operational status. Unknown historical V1 provenance stays explicit in the
legacy record; it must not be inferred into a V2 record.

A V2 leaf or batch must not be treated as reviewed or incident-ready merely
because it appears in the manifest. Use the deployment validators documented in
[`script/README.md`](../script/README.md), and retain the referenced review and
simulation evidence.

## Status and revocation

The intended lifecycle is `deployed` → `reviewed` → `incident-ready`.
`revoked` removes an artifact from incident use without erasing its history;
`superseded` identifies a historical record replaced by another published
artifact. Every transition requires a signed repository commit and evidence in
the applicable review fields. An `incident-ready` record requires approved
direct-use review. Batch-eligible leaves additionally require approved batch-use
review.

The governance process has not yet assigned a permanent owner for publication
and revocation. Until it does, this remains an explicit manual control: the
operator selecting an emergency artifact must identify the canonical repository
ref with the Governance Facilitator, fetch it, verify its commit signature,
confirm that the worktree and submodules are clean, and record that manifest
commit in the incident log. A stale local manifest is never sufficient evidence
after canonical status may have changed.

Deployment validation runs from the exact signed `sourceCommit` recorded for the
artifact. Because deployment records are normally published later, operators
should obtain the canonical manifest from its signed commit as an external file
and pass it to the validator while checked out at `sourceCommit`. The validator
rejects a different or dirty source checkout.

The structured atomic-simulation object is an attestation, not an on-chain
proof. Tooling binds it to the batch address, configuration hash, chain, and
block. Reviewers remain responsible for following its reference and confirming
that the trace demonstrates Chief hat authorization, downstream calls from the
batch address, exact leaf behavior, and atomic rollback on failure.
