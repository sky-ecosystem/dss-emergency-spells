#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
validator="$root/cli/validate-v2-batch-postdeploy.sh"
manifest="$root/test/scripts/fixtures/v2-manifest-valid.json"
batch=0x00000000000000000000000000000000000000b1
factory=0x00000000000000000000000000000000000000f1
tx=0x9999999999999999999999999999999999999999999999999999999999999999
leaf1=0x0000000000000000000000000000000000000011
leaf2=0x0000000000000000000000000000000000000022
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" \
    GIT="$root/test/scripts/mock-git.sh" "$validator" "$manifest" mock:// "$root" "$batch" "$factory" "$tx" create2 \
    "Incident batch" "$leaf1" "$leaf2"

if CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" \
    GIT="$root/test/scripts/mock-git.sh" "$validator" "$manifest" mock:// "$root" "$batch" "$factory" "$tx" create2 \
    "Wrong label" "$leaf1" "$leaf2" >/dev/null 2>&1; then
    echo "expected mismatched label to fail post-deployment validation" >&2
    exit 1
fi

if BROKEN_FACTORY_CALL=1 CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" \
    GIT="$root/test/scripts/mock-git.sh" "$validator" "$manifest" mock:// "$root" "$batch" "$factory" "$tx" create2 \
    "Incident batch" "$leaf1" "$leaf2" >/dev/null 2>&1; then
    echo "expected mismatched factory calldata to fail post-deployment validation" >&2
    exit 1
fi

if BROKEN_EVENT=1 CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" \
    GIT="$root/test/scripts/mock-git.sh" "$validator" "$manifest" mock:// "$root" "$batch" "$factory" "$tx" create2 \
    "Incident batch" "$leaf1" "$leaf2" >/dev/null 2>&1; then
    echo "expected an event from the wrong emitter to fail post-deployment validation" >&2
    exit 1
fi

jq '
    (.records[] | select(.kind == "infrastructure") | .operationalStatus) = "revoked"
    | (.records[] | select(.kind == "batch") | .operationalStatus) = "revoked"
    | (.records[] | select(.kind == "leaf") | .operationalStatus) = "revoked"
' "$manifest" > "$tmpdir/revoked-history.json"
CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" \
    GIT="$root/test/scripts/mock-git.sh" "$validator" "$tmpdir/revoked-history.json" mock:// "$root" "$batch" \
    "$factory" "$tx" create2 "Incident batch" "$leaf1" "$leaf2" >/dev/null

echo "V2 batch post-deployment tests passed"
