#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

jq '.records[0].evidence = ""' "$migration" > "$tmpdir/missing-evidence.json"
expect_invalid "$tmpdir/missing-evidence.json"

jq '.records[0].owner = ""' "$migration" > "$tmpdir/missing-owner.json"
expect_invalid "$tmpdir/missing-owner.json"

jq '.counts.total = 73' "$migration" > "$tmpdir/wrong-counts.json"
expect_invalid "$tmpdir/wrong-counts.json"

jq '
    .records[0].migrationStatus = "superseded-by-v2"
    | .records[0].replacement = "0x0000000000000000000000000000000000000011"
    | .records[0].evidence = "Reviewed incident-ready V2 replacement."
    | .counts.waitingForReviewedV2Replacement -= 1
    | .counts.supersededByV2 += 1
' "$migration" > "$tmpdir/superseded.json"
"$validator" "$legacy" "$root/test/scripts/fixtures/v2-manifest-valid.json" "$tmpdir/superseded.json" >/dev/null
expect_invalid "$tmpdir/superseded.json"

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
