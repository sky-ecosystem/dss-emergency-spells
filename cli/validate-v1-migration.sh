#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: $0 <legacy-v1.json> <v2.json> <v1-migration.json>" >&2
    exit 2
fi

legacy=$1
v2=$2
migration=$3
command -v jq >/dev/null || { echo "validate-v1-migration: jq is required" >&2; exit 2; }
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/validate-v2-manifest.sh" "$v2" >/dev/null || {
    echo "validate-v1-migration: invalid V2 manifest: $v2" >&2
    exit 1
}

jq -e -n \
    --slurpfile legacy "$legacy" \
    --slurpfile v2 "$v2" \
    --slurpfile migration "$migration" '
    def address: type == "string" and test("^0x[0-9a-fA-F]{40}$");
    def nonempty: type == "string" and length > 0;
    def directReplacementAllowed($legacyName; $replacementName):
        if $legacyName == "SPBEAMHaltSpell" then $replacementName == "SPBEAMHaltSpellV2"
        elif $legacyName == "SplitterStopSpell" then $replacementName == "SplitterStopSpellV2"
        elif $legacyName == "MultiClipBreakerSpell" then $replacementName == "GlobalClipBreakerSpellV2"
        elif $legacyName == "MultiLineWipeSpell" then $replacementName == "GlobalLineWipeSpellV2"
        elif $legacyName == "MultiOsmStopSpell" then $replacementName == "GlobalOsmStopSpellV2"
        elif $legacyName == "GroupedClipBreakerFactory" then $replacementName == "EmergencySpellBatchFactoryV2"
        elif $legacyName == "GroupedLineWipeFactory" then $replacementName == "EmergencySpellBatchFactoryV2"
        elif $legacyName == "GroupedClipBreakerSpell" then ($replacementName | IN("ClipBreakerSpellV2", "GlobalClipBreakerSpellV2"))
        elif $legacyName == "GroupedLineWipeSpell" then ($replacementName | IN("LineWipeSpellV2", "GlobalLineWipeSpellV2"))
        elif $legacyName == "SingleDdmDisableSpell" then $replacementName == "DdmDisableSpellV2"
        elif $legacyName == "SingleLitePsmHaltSpell" then $replacementName == "LitePsmHaltSpellV2"
        elif $legacyName == "SingleOsmStopSpell" then $replacementName == "OsmStopSpellV2"
        elif $legacyName == "StUsdsRateSetterDissBudSpell" then $replacementName == "StUsdsRateSetterDissBudSpellV2"
        elif $legacyName == "StUsdsRateSetterHaltSpell" then $replacementName == "StUsdsRateSetterHaltSpellV2"
        elif $legacyName == "StUsdsWipeParamSpell" then $replacementName == "StUsdsWipeParamSpellV2"
        else false end;
    def replacementFamilyAllowed($legacyName; $replacement; $manifest):
        if $replacement.contractName == "EmergencySpellBatchV2" then
            ($legacyName | IN("GroupedClipBreakerSpell", "GroupedLineWipeSpell"))
            and all($replacement.batch.orderedLeaves[];
                . as $leaf
                | any($manifest.records[];
                    (.address | ascii_downcase) == ($leaf | ascii_downcase)
                    and directReplacementAllowed($legacyName; .contractName)))
        else directReplacementAllowed($legacyName; $replacement.contractName) end;
    def identity:
        {name, kind, address, legacySnapshotStatus}
        + (if has("subject") then {subject} else {} end)
        + (if has("parameter") then {parameter} else {} end);
    def counts:
        {
            waitingForReviewedV2Replacement: ([.[] | select(.migrationStatus == "waiting-for-reviewed-v2-replacement")] | length),
            deprecatedV1: ([.[] | select(.migrationStatus == "deprecated-v1")] | length),
            revokedV1: ([.[] | select(.migrationStatus == "revoked-v1")] | length),
            supersededByV2: ([.[] | select(.migrationStatus == "superseded-by-v2")] | length),
            retainedV1Exception: ([.[] | select(.migrationStatus == "retained-v1-exception")] | length),
            total: length
        };

    $legacy[0] as $legacy
    | $v2[0] as $v2
    | $migration[0] as $migration
    | ([ $legacy.active[] | . + {legacySnapshotStatus: "active"} ]
       + [ $legacy.deprecated[] | . + {legacySnapshotStatus: "deprecated"} ]) as $expected
    | $migration
    | type == "object"
    and ([keys[]] - ["schemaVersion", "chainId", "architecture", "sourceSnapshot", "v2ManifestPath", "statusSemantics", "counts", "records"] | length == 0)
    and .schemaVersion == 1
    and .chainId == $legacy.chainId
    and .chainId == $v2.chainId
    and .architecture == "v1-to-v2-migration"
    and .sourceSnapshot == {
        path: "deployments/1/legacy-v1.json",
        tag: $legacy.source.tag,
        commit: $legacy.source.commit
    }
    and .v2ManifestPath == "deployments/1/v2.json"
    and (.statusSemantics | type == "object")
    and ((.statusSemantics | keys | sort) == ([
        "waiting-for-reviewed-v2-replacement",
        "deprecated-v1",
        "revoked-v1",
        "superseded-by-v2",
        "retained-v1-exception"
    ] | sort))
    and all(.statusSemantics[]; nonempty)
    and (.records | type == "array")
    and ((.records | map(identity)) == ($expected | map(identity)))
    and ((.records | map(.address | ascii_downcase) | unique | length) == (.records | length))
    and .counts == (.records | counts)
    and all(.records[];
        . as $record
        | type == "object"
        and ([keys[]] - ["name", "kind", "subject", "parameter", "address", "legacySnapshotStatus", "migrationStatus", "owner", "ownerEvidence", "evidence", "replacement", "retentionRationale", "revocationReason"] | length == 0)
        and (.name | nonempty)
        and (.kind | nonempty)
        and (.address | address)
        and (.owner | nonempty)
        and (.ownerEvidence | nonempty)
        and (.evidence | nonempty)
        and (if .legacySnapshotStatus == "deprecated" then
                 .migrationStatus == "deprecated-v1"
                 and (has("replacement") | not)
                 and (has("retentionRationale") | not)
                 and (has("revocationReason") | not)
             elif .legacySnapshotStatus == "active" then
                 if .migrationStatus == "waiting-for-reviewed-v2-replacement" then
                     (has("replacement") | not)
                     and (has("retentionRationale") | not)
                     and (has("revocationReason") | not)
                 elif .migrationStatus == "revoked-v1" then
                     (.revocationReason | nonempty)
                     and (has("replacement") | not)
                     and (has("retentionRationale") | not)
                 elif .migrationStatus == "superseded-by-v2" then
                     (.replacement | type == "object")
                     and ([.replacement | keys[]] - ["address", "contractName", "coverageReview"] | length == 0)
                     and (.replacement.address | address)
                     and (.replacement.contractName | nonempty)
                     and (has("retentionRationale") | not)
                     and (has("revocationReason") | not)
                     and (([ $v2.records[]
                             | select((.address | ascii_downcase) == ($record.replacement.address | ascii_downcase)) ][0]) as $v2Replacement
                     | $v2Replacement != null
                     and $v2Replacement.operationalStatus == "incident-ready"
                     and $record.replacement.contractName == $v2Replacement.contractName
                     and replacementFamilyAllowed($record.name; $v2Replacement; $v2)
                     and ($record.replacement.coverageReview | type == "object")
                     and ([$record.replacement.coverageReview | keys[]] - [
                         "status",
                         "evidence",
                         "legacyAddress",
                         "legacyName",
                         "legacyKind",
                         "legacySubject",
                         "legacyParameter",
                         "replacementAddress",
                         "replacementContractName",
                         "replacementSubjects",
                         "replacementParameters",
                         "intendedCoverage"
                     ] | length == 0)
                     and $record.replacement.coverageReview.status == "approved"
                     and ($record.replacement.coverageReview.evidence | nonempty)
                     and ($record.replacement.coverageReview.legacyAddress | ascii_downcase) == ($record.address | ascii_downcase)
                     and $record.replacement.coverageReview.legacyName == $record.name
                     and $record.replacement.coverageReview.legacyKind == $record.kind
                     and $record.replacement.coverageReview.legacySubject == ($record.subject // null)
                     and $record.replacement.coverageReview.legacyParameter == ($record.parameter // null)
                     and ($record.replacement.coverageReview.replacementAddress | ascii_downcase) == ($v2Replacement.address | ascii_downcase)
                     and $record.replacement.coverageReview.replacementContractName == $v2Replacement.contractName
                     and $record.replacement.coverageReview.replacementSubjects == $v2Replacement.subjects
                     and $record.replacement.coverageReview.replacementParameters == $v2Replacement.parameters
                     and ($record.replacement.coverageReview.intendedCoverage | nonempty))
                 elif .migrationStatus == "retained-v1-exception" then
                     (.retentionRationale | nonempty)
                     and (has("replacement") | not)
                     and (has("revocationReason") | not)
                 else false end
             else false end)
    )
' >/dev/null || {
    echo "validate-v1-migration: invalid migration record: $migration" >&2
    exit 1
}

echo "Validated V1 migration status: $migration"
