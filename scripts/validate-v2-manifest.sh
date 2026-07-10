#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <v2-manifest.json>" >&2
    exit 2
fi

manifest=$1
command -v jq >/dev/null || { echo "validate-v2-manifest: jq is required" >&2; exit 2; }

jq -e '
    def address: type == "string" and test("^0x[0-9a-fA-F]{40}$");
    def bytes32: type == "string" and test("^0x[0-9a-fA-F]{64}$");
    def commit: type == "string" and test("^[0-9a-f]{40}$");
    def bytes: type == "string" and test("^0x([0-9a-fA-F]{2})*$");
    def nonempty: type == "string" and length > 0;
    def review:
        type == "object"
        and ([keys[]] - ["status", "evidence"] | length == 0)
        and (.status | IN("pending", "approved", "rejected", "not-applicable"))
        and (.evidence | nonempty);
    def deployment:
        type == "object"
        and ([keys[]] - ["transactionHash", "blockNumber", "constructorArguments"] | length == 0)
        and (.transactionHash | bytes32)
        and (.blockNumber | type == "number" and floor == . and . >= 1)
        and (.constructorArguments | bytes);
    def batch:
        type == "object"
        and ([keys[]] - ["label", "orderedLeaves", "configHash", "factory", "deploymentMode", "getterReadbacks", "factoryEventVerified", "atomicSimulationEvidence"] | length == 0)
        and (.label | nonempty)
        and (.orderedLeaves | type == "array" and length > 0 and all(.[]; address))
        and ((.orderedLeaves | map(ascii_downcase) | unique | length) == (.orderedLeaves | length))
        and (.configHash | bytes32)
        and (.factory | address)
        and (.deploymentMode | IN("create", "create2"))
        and (.getterReadbacks | type == "object")
        and (.factoryEventVerified | type == "boolean")
        and (.atomicSimulationEvidence | nonempty);
    def record:
        type == "object"
        and ([keys[]] - ["contractName", "kind", "address", "runtimeCodehash", "sourceCommit", "deployment", "immutableReadbacks", "subjects", "parameters", "reviews", "batchEligible", "operationalStatus", "batch"] | length == 0)
        and (.contractName | nonempty)
        and (.kind | IN("leaf", "registry-global", "batch", "infrastructure"))
        and (.address | address)
        and (.runtimeCodehash | bytes32)
        and (.sourceCommit | commit)
        and (.deployment | deployment)
        and (.immutableReadbacks | type == "object" and all(to_entries[]; (.key | nonempty) and (.value | nonempty)))
        and (.subjects | type == "object")
        and (.parameters | type == "object")
        and (.reviews | type == "object" and ([keys[]] - ["directUse", "batchUse"] | length == 0) and (.directUse | review) and (.batchUse | review))
        and (.batchEligible | type == "boolean")
        and (.operationalStatus | IN("deployed", "reviewed", "incident-ready", "revoked", "superseded"))
        and (if .batchEligible then
                 .kind == "leaf"
                 and .reviews.directUse.status == "approved"
                 and .reviews.batchUse.status == "approved"
             else true end)
        and (if .kind != "leaf" then .batchEligible == false else true end)
        and (if .kind == "batch" then (.batch | batch) else (has("batch") | not) end);

    type == "object"
    and ([keys[]] - ["schemaVersion", "chainId", "architecture", "records"] | length == 0)
    and .schemaVersion == 2
    and (.chainId | type == "number" and floor == . and . >= 1)
    and .architecture == "emergency-spells-v2"
    and (.records | type == "array" and all(.[]; record))
    and ((.records | map(.address | ascii_downcase) | unique | length) == (.records | length))
' "$manifest" >/dev/null || {
    echo "validate-v2-manifest: invalid manifest: $manifest" >&2
    exit 1
}

echo "Validated V2 manifest: $manifest"
