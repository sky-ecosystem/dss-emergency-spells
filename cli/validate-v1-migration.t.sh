#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$root/cli/validate-v1-migration.sh"
legacy="$root/deployments/1/legacy-v1.json"
v2="$root/deployments/1/v2.json"
migration="$root/deployments/1/v1-migration.json"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

expect_invalid() {
    if "$validator" "$legacy" "${2:-$v2}" "$1" >/dev/null 2>&1; then
        echo "expected invalid V1 migration record: $1" >&2
        exit 1
    fi
}

"$validator" "$legacy" "$v2" "$migration"

jq 'del(.records[0]) | .counts.total -= 1 | .counts.waitingForReviewedV2Replacement -= 1' \
    "$migration" > "$tmpdir/missing-record.json"
expect_invalid "$tmpdir/missing-record.json"

jq '.records[0].name = "WrongSpell"' "$migration" > "$tmpdir/wrong-identity.json"
expect_invalid "$tmpdir/wrong-identity.json"

jq '.records[0].migrationStatus = "deprecated-v1"' "$migration" > "$tmpdir/wrong-active-status.json"
expect_invalid "$tmpdir/wrong-active-status.json"

jq '
    .records[0].migrationStatus = "revoked-v1"
    | .records[0].revocationReason = "Withdrawn after failed incident validation."
    | .records[0].evidence = "Approved revocation evidence."
    | .counts.waitingForReviewedV2Replacement -= 1
    | .counts.revokedV1 += 1
' "$migration" > "$tmpdir/revoked.json"
"$validator" "$legacy" "$v2" "$tmpdir/revoked.json" >/dev/null

jq 'del(.records[0].revocationReason)' "$tmpdir/revoked.json" > "$tmpdir/revoked-without-reason.json"
expect_invalid "$tmpdir/revoked-without-reason.json"

jq '.records[0].evidence = ""' "$migration" > "$tmpdir/missing-evidence.json"
expect_invalid "$tmpdir/missing-evidence.json"

jq '.records[0].owner = ""' "$migration" > "$tmpdir/missing-owner.json"
expect_invalid "$tmpdir/missing-owner.json"

jq '.counts.total = 73' "$migration" > "$tmpdir/wrong-counts.json"
expect_invalid "$tmpdir/wrong-counts.json"

jq '.records[0].artifact = "src/osm-stop/OsmStopSpellV2.sol:OsmStopSpellV2"' \
    "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/malformed-v2.json"
expect_invalid "$migration" "$tmpdir/malformed-v2.json"

jq '
    .records[0] as $legacyRecord
    | .records[0].migrationStatus = "superseded-by-v2"
    | .records[0].replacement = {
        address: "0x0000000000000000000000000000000000000044",
        contractName: "SPBEAMHaltSpellV2",
        coverageReview: {
            status: "approved",
            evidence: "https://example.com/spbeam-equivalence-review",
            legacyAddress: $legacyRecord.address,
            legacyName: $legacyRecord.name,
            legacyKind: $legacyRecord.kind,
            legacySubject: null,
            legacyParameter: null,
            replacementAddress: "0x0000000000000000000000000000000000000044",
            replacementContractName: "SPBEAMHaltSpellV2",
            replacementSubjects: {
                "spbeam()(address)": "0x0000000000000000000000000000000000000046",
                "spbeamMom()(address)": "0x0000000000000000000000000000000000000045"
            },
            replacementParameters: {},
            intendedCoverage: "Halt the canonical SPBEAM instance through its emergency mom."
        }
    }
    | .records[0].evidence = "Reviewed equivalent incident-ready V2 replacement."
    | .counts.waitingForReviewedV2Replacement -= 1
    | .counts.supersededByV2 += 1
' "$migration" > "$tmpdir/superseded.json"
"$validator" "$legacy" "$root/cli/fixtures/v2-manifest-valid.json" "$tmpdir/superseded.json" >/dev/null
expect_invalid "$tmpdir/superseded.json"

jq '
    .records[0].replacement.address = "0x0000000000000000000000000000000000000011"
    | .records[0].replacement.contractName = "LineWipeSpellV2"
    | .records[0].replacement.coverageReview.replacementAddress = "0x0000000000000000000000000000000000000011"
    | .records[0].replacement.coverageReview.replacementContractName = "LineWipeSpellV2"
    | .records[0].replacement.coverageReview.replacementSubjects = {
        "ilk()(bytes32)": "0x4554482d41000000000000000000000000000000000000000000000000000000",
        "lineMom()(address)": "0x0000000000000000000000000000000000000021"
    }
' "$tmpdir/superseded.json" > "$tmpdir/wrong-family.json"
expect_invalid "$tmpdir/wrong-family.json" "$root/cli/fixtures/v2-manifest-valid.json"

jq '.records[0].replacement.coverageReview.legacyAddress = "0x0000000000000000000000000000000000000001"' \
    "$tmpdir/superseded.json" > "$tmpdir/unbound-review.json"
expect_invalid "$tmpdir/unbound-review.json" "$root/cli/fixtures/v2-manifest-valid.json"

jq '
    .records[0].replacement.coverageReview.legacySubject = "ETH-A"
    | .records[0].replacement.coverageReview.legacyParameter = "BUY"
' "$tmpdir/superseded.json" > "$tmpdir/wrong-legacy-scope.json"
expect_invalid "$tmpdir/wrong-legacy-scope.json" "$root/cli/fixtures/v2-manifest-valid.json"

jq '.records[0].replacement.coverageReview.replacementSubjects["spbeam()(address)"] = "0x0000000000000000000000000000000000000001"' \
    "$tmpdir/superseded.json" > "$tmpdir/wrong-replacement-scope.json"
expect_invalid "$tmpdir/wrong-replacement-scope.json" "$root/cli/fixtures/v2-manifest-valid.json"

jq '
    .records[0].migrationStatus = "retained-v1-exception"
    | .records[0].retentionRationale = "Reviewed legacy exception."
    | .records[0].evidence = "Approved retention evidence."
    | .counts.waitingForReviewedV2Replacement -= 1
    | .counts.retainedV1Exception += 1
' "$migration" > "$tmpdir/retained.json"
"$validator" "$legacy" "$v2" "$tmpdir/retained.json" >/dev/null

jq 'del(.records[0].retentionRationale)' "$tmpdir/retained.json" > "$tmpdir/retained-without-rationale.json"
expect_invalid "$tmpdir/retained-without-rationale.json"

echo "V1 migration validation tests passed"
