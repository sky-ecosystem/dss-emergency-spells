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

jq -e -n \
    --slurpfile legacy "$legacy" \
    --slurpfile v2 "$v2" \
    --slurpfile migration "$migration" '
    def address: type == "string" and test("^0x[0-9a-fA-F]{40}$");
    def nonempty: type == "string" and length > 0;
    def identity:
        {name, kind, address, legacySnapshotStatus}
        + (if has("subject") then {subject} else {} end)
        + (if has("parameter") then {parameter} else {} end);
    def counts:
        {
            waitingForReviewedV2Replacement: ([.[] | select(.migrationStatus == "waiting-for-reviewed-v2-replacement")] | length),
            deprecatedV1: ([.[] | select(.migrationStatus == "deprecated-v1")] | length),
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
        and ([keys[]] - ["name", "kind", "subject", "parameter", "address", "legacySnapshotStatus", "migrationStatus", "owner", "ownerEvidence", "evidence", "replacement", "retentionRationale"] | length == 0)
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
             elif .legacySnapshotStatus == "active" then
                 if .migrationStatus == "waiting-for-reviewed-v2-replacement" then
                     (has("replacement") | not)
                     and (has("retentionRationale") | not)
                 elif .migrationStatus == "superseded-by-v2" then
                     (.replacement | address)
                     and (has("retentionRationale") | not)
                     and any($v2.records[];
                         (.address | ascii_downcase) == ($record.replacement | ascii_downcase)
                         and .operationalStatus == "incident-ready")
                 elif .migrationStatus == "retained-v1-exception" then
                     (.retentionRationale | nonempty)
                     and (has("replacement") | not)
                 else false end
             else false end)
    )
' >/dev/null || {
    echo "validate-v1-migration: invalid migration record: $migration" >&2
    exit 1
}

echo "Validated V1 migration status: $migration"
