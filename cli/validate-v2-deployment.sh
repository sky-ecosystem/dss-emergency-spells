#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: $0 <v2-manifest.json> <rpc-url> <deployed-address>" >&2
    exit 2
fi

manifest=$1
rpc_url=$2
deployed=$3

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$root/cli/validate-v2-manifest.sh" "$manifest" >/dev/null

cast_bin=${CAST:-cast}
forge_bin=${FORGE:-forge}
git_bin=${GIT:-git}
command -v "$cast_bin" >/dev/null || { echo "validate-v2-deployment: cast is required" >&2; exit 2; }
command -v "$forge_bin" >/dev/null || { echo "validate-v2-deployment: forge is required" >&2; exit 2; }
command -v "$git_bin" >/dev/null || { echo "validate-v2-deployment: git is required" >&2; exit 2; }

manifest_chain_id=$(jq -r '.chainId' "$manifest")
live_chain_id=$($cast_bin chain-id --rpc-url "$rpc_url")
if [[ "$live_chain_id" != "$manifest_chain_id" ]]; then
    echo "validate-v2-deployment: RPC chain ID does not match manifest" >&2
    exit 1
fi

normalized=${deployed,,}
matches=$(jq --arg address "$normalized" '[.records[] | select((.address | ascii_downcase) == $address)] | length' "$manifest")
if [[ "$matches" -ne 1 ]]; then
    echo "validate-v2-deployment: address must resolve to exactly one manifest record" >&2
    exit 1
fi

kind=$(jq -r --arg address "$normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .kind
' "$manifest")
if [[ "$kind" == "batch" ]]; then
    echo "validate-v2-deployment: use validate-v2-batch-postdeploy.sh for batch records" >&2
    exit 2
fi

source_commit=$(jq -r --arg address "$normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .sourceCommit
' "$manifest")
if [[ "$($git_bin -C "$root" rev-parse HEAD)" != "$source_commit" ]]; then
    echo "validate-v2-deployment: repository does not match sourceCommit" >&2
    exit 1
fi
if [[ -n "$($git_bin -C "$root" status --porcelain --untracked-files=all)" ]]; then
    echo "validate-v2-deployment: repository has tracked, untracked, or submodule changes" >&2
    exit 1
fi
$git_bin -C "$root" verify-commit "$source_commit" >/dev/null 2>&1 || {
    echo "validate-v2-deployment: sourceCommit signature verification failed" >&2
    exit 1
}

artifact=$(jq -r --arg address "$normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .artifact
' "$manifest")
constructor_arguments=$(jq -r --arg address "$normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .deployment.constructorArguments
' "$manifest")
creation_code=$($forge_bin inspect --root "$root" --force "$artifact" bytecode)
expected_input="0x${creation_code#0x}${constructor_arguments#0x}"

deployment_tx=$(jq -r --arg address "$normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .deployment.transactionHash
' "$manifest")
transaction=$($cast_bin tx "$deployment_tx" --rpc-url "$rpc_url" --json)
if [[ "$(jq -r '.to' <<<"$transaction")" != "null" ]]; then
    echo "validate-v2-deployment: deployment transaction is not direct CREATE" >&2
    exit 1
fi
actual_input=$(jq -r '.input' <<<"$transaction")
if [[ "${actual_input,,}" != "${expected_input,,}" ]]; then
    echo "validate-v2-deployment: deployment initcode or constructor arguments mismatch" >&2
    exit 1
fi

expected_codehash=$(jq -r --arg address "$normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .runtimeCodehash
' "$manifest")
actual_codehash=$($cast_bin codehash "$deployed" --rpc-url "$rpc_url")
if [[ "${actual_codehash,,}" != "${expected_codehash,,}" ]]; then
    echo "validate-v2-deployment: runtime codehash mismatch" >&2
    exit 1
fi

while IFS= read -r encoded_readback; do
    readback=$(base64 --decode <<<"$encoded_readback")
    signature=$(jq -r '.key' <<<"$readback")
    expected=$(jq -r '.value' <<<"$readback")
    actual=$($cast_bin call "$deployed" "$signature" --rpc-url "$rpc_url")
    if [[ "$actual" == \"*\" ]]; then actual=$(jq -r . <<<"$actual"); fi

    if [[ "$expected" == 0x* && "$actual" == 0x* ]]; then
        expected=${expected,,}
        actual=${actual,,}
    fi
    if [[ "$actual" != "$expected" ]]; then
        echo "validate-v2-deployment: immutable readback mismatch: $signature" >&2
        exit 1
    fi
done < <(jq -r --arg address "$normalized" '
    .records[]
    | select((.address | ascii_downcase) == $address)
    | .immutableReadbacks
    | to_entries[]
    | @base64
' "$manifest")

recorded_block=$(jq -r --arg address "$normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .deployment.blockNumber
' "$manifest")
receipt=$($cast_bin receipt "$deployment_tx" --rpc-url "$rpc_url" --json)
if [[ "$(jq -r '.status' <<<"$receipt")" != "0x1" ]]; then
    echo "validate-v2-deployment: deployment transaction failed" >&2
    exit 1
fi
receipt_contract=$(jq -r '.contractAddress | ascii_downcase' <<<"$receipt")
if [[ "$receipt_contract" != "$normalized" ]]; then
    echo "validate-v2-deployment: receipt contract address mismatch" >&2
    exit 1
fi
receipt_tx=$(jq -r '.transactionHash | ascii_downcase' <<<"$receipt")
if [[ "$receipt_tx" != "${deployment_tx,,}" ]]; then
    echo "validate-v2-deployment: transaction receipt mismatch" >&2
    exit 1
fi
receipt_block=$($cast_bin to-dec "$(jq -r '.blockNumber' <<<"$receipt")")
if [[ "$receipt_block" != "$recorded_block" ]]; then
    echo "validate-v2-deployment: deployment block mismatch" >&2
    exit 1
fi

echo "Validated V2 deployment: $deployed"
