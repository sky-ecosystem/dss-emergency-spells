#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "inspect" && "${!#}" == "bytecode" ]]; then
    if [[ " $* " != *" --force "* || " $* " != *" --root "* ]]; then
        echo "mock-forge: source-root inspection must force compilation" >&2
        exit 2
    fi
    echo "0x6000"
    exit 0
fi

echo "mock-forge: unsupported arguments: $*" >&2
exit 2
