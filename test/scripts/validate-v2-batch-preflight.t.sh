#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
validator="$root/scripts/validate-v2-batch-preflight.sh"
manifest="$root/test/scripts/fixtures/v2-manifest-valid.json"
leaf1=0x0000000000000000000000000000000000000011
leaf2=0x0000000000000000000000000000000000000022
global=0x0000000000000000000000000000000000000031

CAST="$root/test/scripts/mock-cast.sh" "$validator" "$manifest" mock:// create "$leaf2" "$leaf1"
CAST="$root/test/scripts/mock-cast.sh" "$validator" "$manifest" mock:// create2 "$leaf1" "$leaf2"

if CAST="$root/test/scripts/mock-cast.sh" "$validator" "$manifest" mock:// create2 "$leaf2" "$leaf1" >/dev/null 2>&1; then
    echo "expected unordered deterministic leaves to fail preflight" >&2
    exit 1
fi

if CAST="$root/test/scripts/mock-cast.sh" "$validator" "$manifest" mock:// create "$global" >/dev/null 2>&1; then
    echo "expected registry-global record to fail leaf preflight" >&2
    exit 1
fi

echo "V2 batch preflight tests passed"
