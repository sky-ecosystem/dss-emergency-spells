#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "inspect" && "$3" == "bytecode" ]]; then
    echo "0x6000"
    exit 0
fi

echo "mock-forge: unsupported arguments: $*" >&2
exit 2
