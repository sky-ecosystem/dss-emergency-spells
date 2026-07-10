#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
validator="$root/scripts/validate-v2-manifest.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

expect_invalid() {
    if "$validator" "$1" >/dev/null 2>&1; then
        echo "expected invalid V2 manifest: $1" >&2
        exit 1
    fi
}

"$validator" "$root/deployments/1/v2.json"
"$validator" "$root/test/scripts/fixtures/v2-manifest-valid.json"

expect_invalid "$root/test/scripts/fixtures/v2-manifest-invalid-global.json"

jq '
    .records[0].batchEligible = false
    | .records[0].reviews.batchUse.status = "not-applicable"
    | .records[0].reviews.directUse.status = "rejected"
' "$root/test/scripts/fixtures/v2-manifest-valid.json" > "$tmpdir/rejected-incident-ready.json"
expect_invalid "$tmpdir/rejected-incident-ready.json"

jq '
    (.records[] | select(.kind == "batch") | .batch.atomicSimulation.status) = "pending"
' "$root/test/scripts/fixtures/v2-manifest-valid.json" > "$tmpdir/unapproved-simulation.json"
expect_invalid "$tmpdir/unapproved-simulation.json"

jq '
    del(.records[0].immutableReadbacks["vat()(address)"])
' "$root/test/scripts/fixtures/v2-manifest-valid.json" > "$tmpdir/incomplete-readbacks.json"
expect_invalid "$tmpdir/incomplete-readbacks.json"

jq '
    .records[0].artifact = "src/osm-stop/OsmStopSpellV2.sol:OsmStopSpellV2"
' "$root/test/scripts/fixtures/v2-manifest-valid.json" > "$tmpdir/wrong-artifact.json"
expect_invalid "$tmpdir/wrong-artifact.json"

jq '
    (.records[] | select(.kind == "batch") | .batch.getterReadbacks.label) = "Wrong label"
' "$root/test/scripts/fixtures/v2-manifest-valid.json" > "$tmpdir/wrong-batch-readback.json"
expect_invalid "$tmpdir/wrong-batch-readback.json"

jq '
    .records |= map(select(.kind != "infrastructure"))
' "$root/test/scripts/fixtures/v2-manifest-valid.json" > "$tmpdir/missing-factory.json"
expect_invalid "$tmpdir/missing-factory.json"

echo "V2 manifest validation tests passed"
