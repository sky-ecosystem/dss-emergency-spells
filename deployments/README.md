# Deployment records

Deployment records are split by chain ID and architecture generation.

`1/legacy-v1.json` is a signed, versioned Mainnet snapshot copied from the V1
deployment section of `README.md` at the signed `v1-final` tag. It records
historical operational artifacts; inclusion and snapshot status do not imply
that an address is still authoritative.

V2 deployment records will be added separately. A V2 leaf or batch must not be
treated as reviewed or incident-ready merely because it appears in a manifest.
The V2 schema and validation tooling will record and enforce the applicable
direct-use, batch-eligibility, source-review, codehash, and deployment checks.
