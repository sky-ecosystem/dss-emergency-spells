# Deployment records

Deployment records are split by chain ID and architecture generation.

`1/legacy-v1.json` is a signed, versioned Mainnet snapshot copied from the V1
deployment section of `README.md` at the signed `v1-final` tag. It records
historical operational artifacts; inclusion and snapshot status do not imply
that an address is still authoritative.

`<chain-id>/v2.json` is the V2 implementation and review manifest. Its schema is
[`v2.schema.json`](./v2.schema.json), and
[`validate-v2-manifest.sh`](../scripts/validate-v2-manifest.sh) enforces the
cross-field rules that JSON Schema cannot express. In particular:

- only leaf records can be batch-eligible;
- batch-eligible leaves require approved direct-use and batch-use reviews;
- batch preflight accepts only leaves whose operational status is
  `incident-ready`;
- globals, batches, and infrastructure are direct-use only;
- addresses are unique within a manifest;
- batch records include their ordered leaves, factory, deployment mode,
  configuration hash, getter readbacks, event check, and atomic simulation
  evidence.

Every V2 record contains the chain, contract category, address, runtime
codehash, exact source commit, deployment transaction and block, constructor
arguments, immutable getter readbacks, subjects and parameters, review status,
and operational status. Unknown historical V1 provenance stays explicit in the
legacy record; it must not be inferred into a V2 record.

A V2 leaf or batch must not be treated as reviewed or incident-ready merely
because it appears in the manifest. Use the deployment validators documented in
[`script/README.md`](../script/README.md), and retain the referenced review and
simulation evidence.
