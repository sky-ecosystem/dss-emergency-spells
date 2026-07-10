#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
validator="$root/scripts/validate-v2-deployment.sh"
manifest="$root/test/scripts/fixtures/v2-manifest-valid.json"
spell=0x0000000000000000000000000000000000000011

CAST="$root/test/scripts/mock-cast.sh" "$validator" "$manifest" mock:// "$spell"

if CAST="$root/test/scripts/mock-cast.sh" \
    "$validator" "$manifest" mock:// 0x0000000000000000000000000000000000000099 >/dev/null 2>&1; then
    echo "expected an unpublished deployment to fail validation" >&2
    exit 1
fi

echo "V2 deployment validation tests passed"
