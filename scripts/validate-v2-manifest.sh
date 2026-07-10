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
    def spellBase: ["action()(address)", "pause()(address)"];
    def spec:
        if .contractName == "EmergencySpellBatchFactoryV2" then
            {artifact: "src/EmergencySpellBatchFactoryV2.sol:EmergencySpellBatchFactoryV2", kind: "infrastructure", readbacks: []}
        elif .contractName == "EmergencySpellBatchV2" then
            {artifact: "src/EmergencySpellBatchV2.sol:EmergencySpellBatchV2", kind: "batch", readbacks: (spellBase + ["configHash()(bytes32)"])}
        elif .contractName == "LineWipeSpellV2" then
            {artifact: "src/line-wipe/LineWipeSpellV2.sol:LineWipeSpellV2", kind: "leaf", readbacks: (spellBase + ["lineMom()(address)", "autoLine()(address)", "vat()(address)", "ilk()(bytes32)"])}
        elif .contractName == "GlobalLineWipeSpellV2" then
            {artifact: "src/line-wipe/GlobalLineWipeSpellV2.sol:GlobalLineWipeSpellV2", kind: "registry-global", readbacks: (spellBase + ["ilkRegistry()(address)", "lineMom()(address)", "autoLine()(address)", "vat()(address)"])}
        elif .contractName == "ClipBreakerSpellV2" then
            {artifact: "src/clip-breaker/ClipBreakerSpellV2.sol:ClipBreakerSpellV2", kind: "leaf", readbacks: (spellBase + ["clipperMom()(address)", "clip()(address)", "ilk()(bytes32)"])}
        elif .contractName == "GlobalClipBreakerSpellV2" then
            {artifact: "src/clip-breaker/GlobalClipBreakerSpellV2.sol:GlobalClipBreakerSpellV2", kind: "registry-global", readbacks: (spellBase + ["ilkRegistry()(address)", "clipperMom()(address)"])}
        elif .contractName == "DdmDisableSpellV2" then
            {artifact: "src/ddm-disable/DdmDisableSpellV2.sol:DdmDisableSpellV2", kind: "leaf", readbacks: (spellBase + ["ddmMom()(address)", "plan()(address)", "ilk()(bytes32)"])}
        elif .contractName == "LitePsmHaltSpellV2" then
            {artifact: "src/lite-psm-halt/LitePsmHaltSpellV2.sol:LitePsmHaltSpellV2", kind: "leaf", readbacks: (spellBase + ["litePsmMom()(address)", "psm()(address)", "flow()(uint8)", "ilk()(bytes32)"])}
        elif .contractName == "OsmStopSpellV2" then
            {artifact: "src/osm-stop/OsmStopSpellV2.sol:OsmStopSpellV2", kind: "leaf", readbacks: (spellBase + ["osmMom()(address)", "osm()(address)", "ilk()(bytes32)"])}
        elif .contractName == "GlobalOsmStopSpellV2" then
            {artifact: "src/osm-stop/GlobalOsmStopSpellV2.sol:GlobalOsmStopSpellV2", kind: "registry-global", readbacks: (spellBase + ["ilkRegistry()(address)", "osmMom()(address)"])}
        elif .contractName == "SPBEAMHaltSpellV2" then
            {artifact: "src/spbeam-halt/SPBEAMHaltSpellV2.sol:SPBEAMHaltSpellV2", kind: "leaf", readbacks: (spellBase + ["spbeamMom()(address)", "spbeam()(address)"])}
        elif .contractName == "SplitterStopSpellV2" then
            {artifact: "src/splitter-stop/SplitterStopSpellV2.sol:SplitterStopSpellV2", kind: "leaf", readbacks: (spellBase + ["splitterMom()(address)", "splitter()(address)"])}
        elif .contractName == "StUsdsRateSetterDissBudSpellV2" then
            {artifact: "src/stusds/StUsdsRateSetterDissBudSpellV2.sol:StUsdsRateSetterDissBudSpellV2", kind: "leaf", readbacks: (spellBase + ["stUsdsMom()(address)", "rateSetter()(address)", "stUsds()(address)", "bud()(address)"])}
        elif .contractName == "StUsdsRateSetterHaltSpellV2" then
            {artifact: "src/stusds/StUsdsRateSetterHaltSpellV2.sol:StUsdsRateSetterHaltSpellV2", kind: "leaf", readbacks: (spellBase + ["stUsdsMom()(address)", "rateSetter()(address)", "stUsds()(address)"])}
        elif .contractName == "StUsdsWipeParamSpellV2" then
            {artifact: "src/stusds/StUsdsWipeParamSpellV2.sol:StUsdsWipeParamSpellV2", kind: "leaf", readbacks: (spellBase + ["stUsdsMom()(address)", "rateSetter()(address)", "stUsds()(address)", "vat()(address)", "param()(uint8)", "ilk()(bytes32)"])}
        else null end;
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
    def simulation:
        type == "object"
        and ([keys[]] - ["status", "reference", "chainId", "blockNumber", "batch", "configHash", "chief", "chiefAuthorizationVerified", "downstreamCallerVerified", "atomicRollbackVerified"] | length == 0)
        and (.status | IN("pending", "approved", "rejected"))
        and (.reference | nonempty)
        and (.chainId | type == "number" and floor == . and . >= 1)
        and (.blockNumber | type == "number" and floor == . and . >= 1)
        and (.batch | address)
        and (.configHash | bytes32)
        and (.chief | address)
        and (.chiefAuthorizationVerified | type == "boolean")
        and (.downstreamCallerVerified | type == "boolean")
        and (.atomicRollbackVerified | type == "boolean");
    def batch:
        type == "object"
        and ([keys[]] - ["label", "orderedLeaves", "configHash", "factory", "deploymentMode", "getterReadbacks", "factoryEventVerified", "atomicSimulation"] | length == 0)
        and (.label | nonempty)
        and (.orderedLeaves | type == "array" and length > 0 and all(.[]; address))
        and ((.orderedLeaves | map(ascii_downcase) | unique | length) == (.orderedLeaves | length))
        and (.configHash | bytes32)
        and (.factory | address)
        and (.deploymentMode | IN("create", "create2"))
        and (.getterReadbacks | type == "object" and ([keys[]] - ["label", "leaves", "configHash"] | length == 0))
        and (.getterReadbacks.label | nonempty)
        and (.getterReadbacks.leaves | type == "array" and length > 0 and all(.[]; address))
        and (.getterReadbacks.configHash | bytes32)
        and (.factoryEventVerified | type == "boolean")
        and (.atomicSimulation | simulation);
    def record($chainId):
        . as $record
        | (spec) as $spec
        | type == "object"
        and ([keys[]] - ["contractName", "artifact", "kind", "address", "runtimeCodehash", "sourceCommit", "deployment", "immutableReadbacks", "subjects", "parameters", "reviews", "batchEligible", "operationalStatus", "batch"] | length == 0)
        and (.contractName | nonempty)
        and $spec != null
        and .artifact == $spec.artifact
        and .kind == $spec.kind
        and (.kind | IN("leaf", "registry-global", "batch", "infrastructure"))
        and (.address | address)
        and (.runtimeCodehash | bytes32)
        and (.sourceCommit | commit)
        and (.deployment | deployment)
        and (if .contractName == "EmergencySpellBatchFactoryV2" then
                 .deployment.constructorArguments == "0x"
             else .deployment.constructorArguments != "0x" end)
        and (.immutableReadbacks | type == "object" and all(to_entries[]; (.key | nonempty) and (.value | nonempty)))
        and ((.immutableReadbacks | keys | sort) == ($spec.readbacks | sort))
        and (.subjects | type == "object")
        and (if .kind == "leaf" or .kind == "registry-global" then (.subjects | length > 0) else true end)
        and (.parameters | type == "object")
        and (.reviews | type == "object" and ([keys[]] - ["directUse", "batchUse"] | length == 0) and (.directUse | review) and (.batchUse | review))
        and (.batchEligible | type == "boolean")
        and (.operationalStatus | IN("deployed", "reviewed", "incident-ready", "revoked", "superseded"))
        and (if .operationalStatus == "incident-ready" then .reviews.directUse.status == "approved" else true end)
        and (if .batchEligible then
                 .kind == "leaf"
                 and .reviews.directUse.status == "approved"
                 and .reviews.batchUse.status == "approved"
             else true end)
        and (if .reviews.batchUse.status == "approved" then .kind == "leaf" and .batchEligible else true end)
        and (if .kind != "leaf" then .batchEligible == false and .reviews.batchUse.status == "not-applicable" else true end)
        and (if .kind == "batch" then
                 (.batch | batch)
                 and .batch.getterReadbacks.label == .batch.label
                 and ((.batch.getterReadbacks.leaves | map(ascii_downcase)) == (.batch.orderedLeaves | map(ascii_downcase)))
                 and .batch.getterReadbacks.configHash == .batch.configHash
                 and .batch.atomicSimulation.chainId == $chainId
                 and .batch.atomicSimulation.blockNumber >= .deployment.blockNumber
                 and (.batch.atomicSimulation.batch | ascii_downcase) == (.address | ascii_downcase)
                 and .batch.atomicSimulation.configHash == .batch.configHash
                 and (if .operationalStatus == "incident-ready" then
                          .batch.factoryEventVerified
                          and .batch.atomicSimulation.status == "approved"
                          and .batch.atomicSimulation.chiefAuthorizationVerified
                          and .batch.atomicSimulation.downstreamCallerVerified
                          and .batch.atomicSimulation.atomicRollbackVerified
                      else true end)
             else (has("batch") | not) end);

    . as $manifest
    | type == "object"
    and ([keys[]] - ["schemaVersion", "chainId", "architecture", "records"] | length == 0)
    and .schemaVersion == 2
    and (.chainId | type == "number" and floor == . and . >= 1)
    and .architecture == "emergency-spells-v2"
    and (.records | type == "array" and all(.[]; record($manifest.chainId)))
    and ((.records | map(.address | ascii_downcase) | unique | length) == (.records | length))
    and all(.records[];
        if .kind == "batch" then
            . as $batchRecord
            | (.batch.factory | ascii_downcase) as $factory
            | any($manifest.records[];
                (.address | ascii_downcase) == $factory
                and .contractName == "EmergencySpellBatchFactoryV2"
                and .kind == "infrastructure"
                and .operationalStatus == "incident-ready"
                and .sourceCommit == $batchRecord.sourceCommit)
        else true end)
' "$manifest" >/dev/null || {
    echo "validate-v2-manifest: invalid manifest: $manifest" >&2
    exit 1
}

echo "Validated V2 manifest: $manifest"
