#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 8 ]]; then
    echo "usage: $0 <v2-manifest.json> <rpc-url> <batch> <factory> <deployment-tx> <create|create2> <label> <leaf> [leaf ...]" >&2
    exit 2
fi

manifest=$1
rpc_url=$2
batch=$3
factory=$4
deployment_tx=$5
mode=$6
label=$7
shift 7
leaves=("$@")

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$root/cli/validate-v2-manifest.sh" "$manifest" >/dev/null

cast_bin=${CAST:-cast}
forge_bin=${FORGE:-forge}
git_bin=${GIT:-git}
command -v "$cast_bin" >/dev/null || { echo "validate-v2-batch-postdeploy: cast is required" >&2; exit 2; }
command -v "$git_bin" >/dev/null || { echo "validate-v2-batch-postdeploy: git is required" >&2; exit 2; }

manifest_chain_id=$(jq -r '.chainId' "$manifest")
live_chain_id=$($cast_bin chain-id --rpc-url "$rpc_url")
if [[ "$live_chain_id" != "$manifest_chain_id" ]]; then
    echo "validate-v2-batch-postdeploy: RPC chain ID does not match manifest" >&2
    exit 1
fi

factory_normalized=${factory,,}
factory_matches=$(jq --arg address "$factory_normalized" '[.records[] | select((.address | ascii_downcase) == $address and .kind == "infrastructure" and .contractName == "EmergencySpellBatchFactoryV2")] | length' "$manifest")
if [[ "$factory_matches" -ne 1 ]]; then
    echo "validate-v2-batch-postdeploy: expected factory record not found" >&2
    exit 1
fi
"$root/cli/validate-v2-deployment.sh" "$manifest" "$rpc_url" "$factory" >/dev/null

leaves_json=$(printf '%s\n' "${leaves[@]}" | jq -R . | jq -s 'map(ascii_downcase)')
batch_normalized=${batch,,}
tx_normalized=${deployment_tx,,}

for leaf in "${leaves[@]}"; do
    leaf_normalized=${leaf,,}
    expected_leaf_codehash=$(jq -r --arg address "$leaf_normalized" '
        .records[] | select((.address | ascii_downcase) == $address and .kind == "leaf") | .runtimeCodehash
    ' "$manifest")
    actual_leaf_codehash=$($cast_bin codehash "$leaf" --rpc-url "$rpc_url")
    if [[ -z "$expected_leaf_codehash" || "${actual_leaf_codehash,,}" != "${expected_leaf_codehash,,}" ]]; then
        echo "validate-v2-batch-postdeploy: leaf runtime codehash mismatch: $leaf" >&2
        exit 1
    fi
done

matches=$(jq --arg address "$batch_normalized" '[.records[] | select((.address | ascii_downcase) == $address)] | length' "$manifest")
if [[ "$matches" -ne 1 ]]; then
    echo "validate-v2-batch-postdeploy: batch must resolve to exactly one manifest record" >&2
    exit 1
fi

record_matches=$(jq -r \
    --arg address "$batch_normalized" \
    --arg factory "$factory_normalized" \
    --arg tx "$tx_normalized" \
    --arg mode "$mode" \
    --arg label "$label" \
    --argjson leaves "$leaves_json" '
        .records[]
        | select((.address | ascii_downcase) == $address)
        | .kind == "batch"
          and (.deployment.transactionHash | ascii_downcase) == $tx
          and (.batch.factory | ascii_downcase) == $factory
          and .batch.deploymentMode == $mode
          and .batch.label == $label
          and (.batch.orderedLeaves | map(ascii_downcase)) == $leaves
          and .batch.factoryEventVerified == true
    ' "$manifest")
if [[ "$record_matches" != "true" ]]; then
    echo "validate-v2-batch-postdeploy: manifest batch configuration mismatch" >&2
    exit 1
fi

source_commit=$(jq -r --arg address "$batch_normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .sourceCommit
' "$manifest")
if [[ "$($git_bin -C "$root" rev-parse HEAD)" != "$source_commit" ]]; then
    echo "validate-v2-batch-postdeploy: repository does not match batch sourceCommit" >&2
    exit 1
fi

separator=
leaves_argument="["
for leaf in "${leaves[@]}"; do
    leaves_argument+="$separator$leaf"
    separator=,
done
leaves_argument+="]"

encoded=$($cast_bin abi-encode "f(address[],string)" "$leaves_argument" "$label")
expected_config_hash=$($cast_bin keccak "$encoded")
recorded_constructor_arguments=$(jq -r --arg address "$batch_normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .deployment.constructorArguments
' "$manifest")
if [[ "${recorded_constructor_arguments,,}" != "${encoded,,}" ]]; then
    echo "validate-v2-batch-postdeploy: batch constructor arguments mismatch" >&2
    exit 1
fi
recorded_config_hash=$(jq -r --arg address "$batch_normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .batch.configHash
' "$manifest")
if [[ "${expected_config_hash,,}" != "${recorded_config_hash,,}" ]]; then
    echo "validate-v2-batch-postdeploy: manifest config hash mismatch" >&2
    exit 1
fi

label_readback=$($cast_bin call "$batch" "label()(string)" --rpc-url "$rpc_url")
if [[ "$label_readback" == \"*\" ]]; then
    label_readback=$(jq -r . <<<"$label_readback")
fi
if [[ "$label_readback" != "$label" ]]; then
    echo "validate-v2-batch-postdeploy: label readback mismatch" >&2
    exit 1
fi

leaves_readback=$($cast_bin call "$batch" "leaves()(address[])" --rpc-url "$rpc_url")
leaves_readback=${leaves_readback//[[:space:]]/}
if [[ "${leaves_readback,,}" != "${leaves_argument,,}" ]]; then
    echo "validate-v2-batch-postdeploy: leaf readback mismatch" >&2
    exit 1
fi

config_hash_readback=$($cast_bin call "$batch" "configHash()(bytes32)" --rpc-url "$rpc_url")
if [[ "${config_hash_readback,,}" != "${expected_config_hash,,}" ]]; then
    echo "validate-v2-batch-postdeploy: config hash readback mismatch" >&2
    exit 1
fi

expected_runtime_codehash=$(jq -r --arg address "$batch_normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .runtimeCodehash
' "$manifest")
actual_runtime_codehash=$($cast_bin codehash "$batch" --rpc-url "$rpc_url")
if [[ "${actual_runtime_codehash,,}" != "${expected_runtime_codehash,,}" ]]; then
    echo "validate-v2-batch-postdeploy: batch runtime codehash mismatch" >&2
    exit 1
fi

while IFS= read -r encoded_readback; do
    readback=$(base64 --decode <<<"$encoded_readback")
    signature=$(jq -r '.key' <<<"$readback")
    expected=$(jq -r '.value' <<<"$readback")
    actual=$($cast_bin call "$batch" "$signature" --rpc-url "$rpc_url")
    if [[ "$expected" == 0x* && "$actual" == 0x* ]]; then
        expected=${expected,,}
        actual=${actual,,}
    fi
    if [[ "$actual" != "$expected" ]]; then
        echo "validate-v2-batch-postdeploy: immutable readback mismatch: $signature" >&2
        exit 1
    fi
done < <(jq -r --arg address "$batch_normalized" '
    .records[]
    | select((.address | ascii_downcase) == $address)
    | .immutableReadbacks
    | to_entries[]
    | @base64
' "$manifest")

factory_function="deploy(address[],string)"
if [[ "$mode" == "create2" ]]; then factory_function="deployDeterministic(address[],string)"; fi
expected_transaction_input=$($cast_bin calldata "$factory_function" "$leaves_argument" "$label")
transaction=$($cast_bin tx "$deployment_tx" --rpc-url "$rpc_url" --json)
transaction_to=$(jq -r '.to | ascii_downcase' <<<"$transaction")
transaction_input=$(jq -r '.input | ascii_downcase' <<<"$transaction")
if [[ "$transaction_to" != "$factory_normalized" || "$transaction_input" != "${expected_transaction_input,,}" ]]; then
    echo "validate-v2-batch-postdeploy: factory call target or calldata mismatch" >&2
    exit 1
fi

receipt=$($cast_bin receipt "$deployment_tx" --rpc-url "$rpc_url" --json)
if [[ "$(jq -r '.status' <<<"$receipt")" != "0x1" ]]; then
    echo "validate-v2-batch-postdeploy: deployment transaction failed" >&2
    exit 1
fi
receipt_tx=$(jq -r '.transactionHash | ascii_downcase' <<<"$receipt")
if [[ "$receipt_tx" != "$tx_normalized" ]]; then
    echo "validate-v2-batch-postdeploy: transaction receipt mismatch" >&2
    exit 1
fi
receipt_block=$($cast_bin to-dec "$(jq -r '.blockNumber' <<<"$receipt")")
recorded_block=$(jq -r --arg address "$batch_normalized" '
    .records[] | select((.address | ascii_downcase) == $address) | .deployment.blockNumber
' "$manifest")
if [[ "$receipt_block" != "$recorded_block" ]]; then
    echo "validate-v2-batch-postdeploy: deployment block mismatch" >&2
    exit 1
fi

event_signature=$($cast_bin keccak "BatchDeployed(address,bytes32,uint8)")
batch_topic="0x$(printf '%064s' "${batch_normalized#0x}" | tr ' ' 0)"
mode_value=0
if [[ "$mode" == "create2" ]]; then mode_value=1; fi
mode_data=$(printf '0x%064x' "$mode_value")
event_matches=$(jq \
    --arg factory "$factory_normalized" \
    --arg signature "${event_signature,,}" \
    --arg batch "${batch_topic,,}" \
    --arg config "${expected_config_hash,,}" \
    --arg data "${mode_data,,}" '
        [.logs[]
         | select((.address | ascii_downcase) == $factory)
         | select((.topics[0] | ascii_downcase) == $signature)
         | select((.topics[1] | ascii_downcase) == $batch)
         | select((.topics[2] | ascii_downcase) == $config)
         | select((.data | ascii_downcase) == $data)]
        | length
    ' <<<"$receipt")
if [[ "$event_matches" -ne 1 ]]; then
    echo "validate-v2-batch-postdeploy: expected factory event not found" >&2
    exit 1
fi

if [[ "$mode" == "create2" ]]; then
    command -v "$forge_bin" >/dev/null || { echo "validate-v2-batch-postdeploy: forge is required for CREATE2 validation" >&2; exit 2; }
    batch_artifact=$(jq -r --arg address "$batch_normalized" '
        .records[] | select((.address | ascii_downcase) == $address) | .artifact
    ' "$manifest")
    creation_code=$($forge_bin inspect --root "$root" --force "$batch_artifact" bytecode)
    init_code="0x${creation_code#0x}${encoded#0x}"
    predicted=$($cast_bin create2 --deployer "$factory" --salt "$expected_config_hash" --init-code "$init_code")
    if [[ "${predicted,,}" != "$batch_normalized" ]]; then
        echo "validate-v2-batch-postdeploy: independent CREATE2 address mismatch" >&2
        exit 1
    fi
fi

echo "Validated V2 batch deployment: $batch"
echo "Validated the configuration-bound simulation attestation; reviewers must verify its external trace."
