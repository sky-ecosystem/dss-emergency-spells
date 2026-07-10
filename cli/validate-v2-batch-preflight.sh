#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 6 ]]; then
    echo "usage: $0 <v2-manifest.json> <rpc-url> <factory> <create|create2> <label> <leaf> [leaf ...]" >&2
    exit 2
fi

manifest=$1
rpc_url=$2
factory=$3
mode=$4
label=$5
shift 5
leaves=("$@")

case "$mode" in
    create | create2) ;;
    *) echo "validate-v2-batch-preflight: mode must be create or create2" >&2; exit 2 ;;
esac
if [[ -z "$label" ]]; then
    echo "validate-v2-batch-preflight: label must not be empty" >&2
    exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$root/cli/validate-v2-manifest.sh" "$manifest" >/dev/null

cast_bin=${CAST:-cast}
command -v "$cast_bin" >/dev/null || {
    echo "validate-v2-batch-preflight: cast is required" >&2
    exit 2
}

manifest_chain_id=$(jq -r '.chainId' "$manifest")
live_chain_id=$($cast_bin chain-id --rpc-url "$rpc_url")
if [[ "$live_chain_id" != "$manifest_chain_id" ]]; then
    echo "validate-v2-batch-preflight: RPC chain ID does not match manifest" >&2
    exit 1
fi

factory_normalized=${factory,,}
factory_matches=$(jq --arg address "$factory_normalized" '[.records[] | select((.address | ascii_downcase) == $address)] | length' "$manifest")
if [[ "$factory_matches" -ne 1 ]]; then
    echo "validate-v2-batch-preflight: factory must resolve to exactly one manifest record" >&2
    exit 1
fi
factory_ready=$(jq -r --arg address "$factory_normalized" '
    .records[]
    | select((.address | ascii_downcase) == $address)
    | .contractName == "EmergencySpellBatchFactoryV2"
      and .kind == "infrastructure"
      and .reviews.directUse.status == "approved"
      and .operationalStatus == "incident-ready"
' "$manifest")
if [[ "$factory_ready" != "true" ]]; then
    echo "validate-v2-batch-preflight: factory is not incident-ready infrastructure" >&2
    exit 1
fi
"$root/cli/validate-v2-deployment.sh" "$manifest" "$rpc_url" "$factory" >/dev/null

declare -A selected
previous=

for leaf in "${leaves[@]}"; do
    normalized=${leaf,,}
    if [[ -n "${selected[$normalized]:-}" ]]; then
        echo "validate-v2-batch-preflight: duplicate leaf: $leaf" >&2
        exit 1
    fi
    selected[$normalized]=1

    if [[ "$mode" == "create2" && -n "$previous" && "$previous" > "$normalized" ]]; then
        echo "validate-v2-batch-preflight: deterministic leaves are not strictly ordered" >&2
        exit 1
    fi
    previous=$normalized

    matches=$(jq --arg address "$normalized" '[.records[] | select((.address | ascii_downcase) == $address)] | length' "$manifest")
    if [[ "$matches" -ne 1 ]]; then
        echo "validate-v2-batch-preflight: leaf must resolve to exactly one manifest record: $leaf" >&2
        exit 1
    fi

    eligible=$(jq -r --arg address "$normalized" '
        .records[]
        | select((.address | ascii_downcase) == $address)
        | .kind == "leaf"
          and .batchEligible == true
          and .reviews.directUse.status == "approved"
          and .reviews.batchUse.status == "approved"
          and .operationalStatus == "incident-ready"
    ' "$manifest")
    if [[ "$eligible" != "true" ]]; then
        echo "validate-v2-batch-preflight: leaf is not incident-ready for batch use: $leaf" >&2
        exit 1
    fi

    expected=$(jq -r --arg address "$normalized" '
        .records[] | select((.address | ascii_downcase) == $address) | .runtimeCodehash
    ' "$manifest")
    actual=$($cast_bin codehash "$leaf" --rpc-url "$rpc_url")
    if [[ "${actual,,}" != "${expected,,}" ]]; then
        echo "validate-v2-batch-preflight: runtime codehash mismatch: $leaf" >&2
        exit 1
    fi
done

separator=
leaves_argument="["
for leaf in "${leaves[@]}"; do
    leaves_argument+="$separator$leaf"
    separator=,
done
leaves_argument+="]"
encoded=$($cast_bin abi-encode "f(address[],string)" "$leaves_argument" "$label")
config_hash=$($cast_bin keccak "$encoded")

echo "Validated V2 batch preflight: ${#leaves[@]} leaf/leaves ($mode)"
echo "Config hash: $config_hash"
if [[ "$mode" == "create2" ]]; then
    predicted=$($cast_bin call "$factory" "previewDeterministicAddress(address[],string)(address)" "$leaves_argument" "$label" --rpc-url "$rpc_url")
    echo "Predicted batch: $predicted"
fi
