#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
validator="$root/cli/validate-v2-deployment.sh"
manifest="$root/test/scripts/fixtures/v2-manifest-valid.json"
spell=0x0000000000000000000000000000000000000011

CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" GIT="$root/test/scripts/mock-git.sh" \
    "$validator" "$manifest" mock:// "$root" "$spell"

if CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" GIT="$root/test/scripts/mock-git.sh" \
    "$validator" "$manifest" mock:// "$root" 0x0000000000000000000000000000000000000099 >/dev/null 2>&1; then
    echo "expected an unpublished deployment to fail validation" >&2
    exit 1
fi

if BROKEN_TX_INPUT=1 CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" \
    GIT="$root/test/scripts/mock-git.sh" "$validator" "$manifest" mock:// "$root" "$spell" >/dev/null 2>&1; then
    echo "expected mismatched deployment initcode to fail validation" >&2
    exit 1
fi

if BROKEN_SOURCE=1 CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" \
    GIT="$root/test/scripts/mock-git.sh" "$validator" "$manifest" mock:// "$root" "$spell" >/dev/null 2>&1; then
    echo "expected the wrong source checkout to fail validation" >&2
    exit 1
fi

if BROKEN_RECEIPT_ADDRESS=1 CAST="$root/test/scripts/mock-cast.sh" FORGE="$root/test/scripts/mock-forge.sh" \
    GIT="$root/test/scripts/mock-git.sh" "$validator" "$manifest" mock:// "$root" "$spell" >/dev/null 2>&1; then
    echo "expected an unrelated CREATE receipt to fail validation" >&2
    exit 1
fi

echo "V2 deployment validation tests passed"
