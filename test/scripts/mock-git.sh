#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "-C" ]]; then shift 2; fi

case "$1" in
    rev-parse)
        if [[ "${BROKEN_SOURCE:-0}" == "1" ]]; then
            echo "2222222222222222222222222222222222222222"
        else
            echo "1111111111111111111111111111111111111111"
        fi
        ;;
    status)
        if [[ " $* " != *" --untracked-files=all "* ]]; then
            echo "mock-git: source status must include untracked files" >&2
            exit 2
        fi
        if [[ "${UNTRACKED_SOURCE:-0}" == "1" ]]; then
            echo "?? remappings.txt"
        fi
        ;;
    verify-commit)
        ;;
    *)
        echo "mock-git: unsupported arguments: $*" >&2
        exit 2
        ;;
esac
