#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$root/cli/validate-v2-manifest.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

expect_invalid() {
    if "$validator" "$1" >/dev/null 2>&1; then
        echo "expected invalid V2 manifest: $1" >&2
        exit 1
    fi
}

expect_valid() {
    "$validator" "$1" >/dev/null
}

"$validator" "$root/deployments/1/v2.json"
"$validator" "$root/cli/fixtures/v2-manifest-valid.json"

expect_invalid "$root/cli/fixtures/v2-manifest-invalid-global.json"

jq '
    .records[0].batchEligible = false
    | .records[0].reviews.batchUse.status = "not-applicable"
    | .records[0].reviews.directUse.status = "rejected"
' "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/rejected-incident-ready.json"
expect_invalid "$tmpdir/rejected-incident-ready.json"

jq '
    (.records[] | select(.kind == "batch") | .batch.atomicSimulation.status) = "pending"
' "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/unapproved-simulation.json"
expect_invalid "$tmpdir/unapproved-simulation.json"

jq '
    del(.records[0].immutableReadbacks["vat()(address)"])
' "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/incomplete-readbacks.json"
expect_invalid "$tmpdir/incomplete-readbacks.json"

jq '
    .records[0].artifact = "src/osm-stop/OsmStopSpellV2.sol:OsmStopSpellV2"
' "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/wrong-artifact.json"
expect_invalid "$tmpdir/wrong-artifact.json"

jq '
    (.records[] | select(.kind == "batch") | .batch.getterReadbacks.label) = "Wrong label"
' "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/wrong-batch-readback.json"
expect_invalid "$tmpdir/wrong-batch-readback.json"

jq '
    .records |= map(select(.kind != "infrastructure"))
' "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/missing-factory.json"
expect_invalid "$tmpdir/missing-factory.json"

jq '
    (.records[] | select(.kind == "infrastructure") | .operationalStatus) = "revoked"
    | (.records[] | select(.kind == "batch") | .operationalStatus) = "revoked"
' "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/revoked-factory-history.json"
expect_valid "$tmpdir/revoked-factory-history.json"

jq '
    .records[0].operationalStatus = "revoked"
    | (.records[] | select(.kind == "batch") | .operationalStatus) = "revoked"
' "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/revoked-leaf-history.json"
expect_valid "$tmpdir/revoked-leaf-history.json"

jq '.records[0].operationalStatus = "revoked"' \
    "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/ready-batch-revoked-leaf.json"
expect_invalid "$tmpdir/ready-batch-revoked-leaf.json"

jq '(.records[] | select(.kind == "infrastructure") | .operationalStatus) = "revoked"' \
    "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/ready-batch-revoked-factory.json"
expect_invalid "$tmpdir/ready-batch-revoked-factory.json"

jq '(.records[] | select(.kind == "infrastructure") | .deployment.blockNumber) = 5' \
    "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/factory-after-batch.json"
expect_invalid "$tmpdir/factory-after-batch.json"

jq '.records[0].deployment.blockNumber = 5' \
    "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/leaf-after-batch.json"
expect_invalid "$tmpdir/leaf-after-batch.json"

jq '.records |= map(select(.address != "0x0000000000000000000000000000000000000011"))' \
    "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/missing-leaf.json"
expect_invalid "$tmpdir/missing-leaf.json"

jq '.records[0].subjects["ilk()(bytes32)"] = "0x575442432d410000000000000000000000000000000000000000000000000000"' \
    "$root/cli/fixtures/v2-manifest-valid.json" > "$tmpdir/mismatched-subject.json"
expect_invalid "$tmpdir/mismatched-subject.json"

echo "V2 manifest validation tests passed"
