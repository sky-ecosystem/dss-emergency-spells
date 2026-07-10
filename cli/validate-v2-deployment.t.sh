#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$root/cli/validate-v2-deployment.sh"
manifest="$root/cli/fixtures/v2-manifest-valid.json"
spell=0x0000000000000000000000000000000000000011

CAST="$root/cli/mock-cast.sh" FORGE="$root/cli/mock-forge.sh" GIT="$root/cli/mock-git.sh" \
    "$validator" "$manifest" mock:// "$spell"

if CAST="$root/cli/mock-cast.sh" FORGE="$root/cli/mock-forge.sh" GIT="$root/cli/mock-git.sh" \
    "$validator" "$manifest" mock:// 0x0000000000000000000000000000000000000099 >/dev/null 2>&1; then
    echo "expected an unpublished deployment to fail validation" >&2
    exit 1
fi

if BROKEN_TX_INPUT=1 CAST="$root/cli/mock-cast.sh" FORGE="$root/cli/mock-forge.sh" \
    GIT="$root/cli/mock-git.sh" "$validator" "$manifest" mock:// "$spell" >/dev/null 2>&1; then
    echo "expected mismatched deployment initcode to fail validation" >&2
    exit 1
fi

if BROKEN_SOURCE=1 CAST="$root/cli/mock-cast.sh" FORGE="$root/cli/mock-forge.sh" \
    GIT="$root/cli/mock-git.sh" "$validator" "$manifest" mock:// "$spell" >/dev/null 2>&1; then
    echo "expected the wrong source checkout to fail validation" >&2
    exit 1
fi

if BROKEN_RECEIPT_ADDRESS=1 CAST="$root/cli/mock-cast.sh" FORGE="$root/cli/mock-forge.sh" \
    GIT="$root/cli/mock-git.sh" "$validator" "$manifest" mock:// "$spell" >/dev/null 2>&1; then
    echo "expected an unrelated CREATE receipt to fail validation" >&2
    exit 1
fi

if UNTRACKED_SOURCE=1 CAST="$root/cli/mock-cast.sh" FORGE="$root/cli/mock-forge.sh" \
    GIT="$root/cli/mock-git.sh" "$validator" "$manifest" mock:// "$spell" >/dev/null 2>&1; then
    echo "expected an untracked repository source to fail validation" >&2
    exit 1
fi

echo "V2 deployment validation tests passed"
