#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
validator="$root/scripts/validate-v2-manifest.sh"

"$validator" "$root/deployments/1/v2.json"
"$validator" "$root/test/scripts/fixtures/v2-manifest-valid.json"

if "$validator" "$root/test/scripts/fixtures/v2-manifest-invalid-global.json" >/dev/null 2>&1; then
    echo "expected direct-use-only global record to fail validation" >&2
    exit 1
fi

echo "V2 manifest validation tests passed"
