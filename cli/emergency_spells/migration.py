from .common.manifest import validate_manifest
from .common.validation import (
    ADDRESS_RE,
    ValidationError,
    matches as _matches,
    nonempty as _nonempty,
    object_ as _object,
    require as _require,
)


DIRECT_REPLACEMENTS = {
    "SPBEAMHaltSpell": {"SPBEAMHaltSpellV2"},
    "SplitterStopSpell": {"SplitterStopSpellV2"},
    "MultiClipBreakerSpell": {"GlobalClipBreakerSpellV2"},
    "MultiLineWipeSpell": {"GlobalLineWipeSpellV2"},
    "MultiOsmStopSpell": {"GlobalOsmStopSpellV2"},
    "GroupedClipBreakerFactory": {"EmergencySpellBatchFactoryV2"},
    "GroupedLineWipeFactory": {"EmergencySpellBatchFactoryV2"},
    "GroupedClipBreakerSpell": {"ClipBreakerSpellV2", "GlobalClipBreakerSpellV2"},
    "GroupedLineWipeSpell": {"LineWipeSpellV2", "GlobalLineWipeSpellV2"},
    "SingleDdmDisableSpell": {"DdmDisableSpellV2"},
    "SingleLitePsmHaltSpell": {"LitePsmHaltSpellV2"},
    "SingleOsmStopSpell": {"OsmStopSpellV2"},
    "StUsdsRateSetterDissBudSpell": {"StUsdsRateSetterDissBudSpellV2"},
    "StUsdsRateSetterHaltSpell": {"StUsdsRateSetterHaltSpellV2"},
    "StUsdsWipeParamSpell": {"StUsdsWipeParamSpellV2"},
}

STATUSES = {
    "waiting-for-reviewed-v2-replacement": "waitingForReviewedV2Replacement",
    "deprecated-v1": "deprecatedV1",
    "revoked-v1": "revokedV1",
    "superseded-by-v2": "supersededByV2",
    "retained-v1-exception": "retainedV1Exception",
}

RECORD_KEYS = {
    "name",
    "kind",
    "subject",
    "parameter",
    "address",
    "legacySnapshotStatus",
    "migrationStatus",
    "owner",
    "ownerEvidence",
    "evidence",
    "replacement",
    "retentionRationale",
    "revocationReason",
}

COVERAGE_KEYS = {
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
    "intendedCoverage",
}


def _identity(record):
    result = {
        "name": record.get("name"),
        "kind": record.get("kind"),
        "address": record.get("address"),
        "legacySnapshotStatus": record.get("legacySnapshotStatus"),
    }
    for field in ("subject", "parameter"):
        if field in record:
            result[field] = record[field]
    return result


def _expected_records(legacy):
    return [
        dict(record, legacySnapshotStatus="active") for record in legacy["active"]
    ] + [
        dict(record, legacySnapshotStatus="deprecated")
        for record in legacy["deprecated"]
    ]


def _replacement_allowed(legacy_name, replacement, v2_by_address):
    name = replacement["contractName"]
    if name != "EmergencySpellBatchV2":
        return name in DIRECT_REPLACEMENTS.get(legacy_name, set())
    if legacy_name not in {"GroupedClipBreakerSpell", "GroupedLineWipeSpell"}:
        return False
    return all(
        v2_by_address[leaf.lower()]["contractName"] in DIRECT_REPLACEMENTS[legacy_name]
        for leaf in replacement["batch"]["orderedLeaves"]
    )


def _validate_coverage(record, replacement, path):
    review = record["replacement"]["coverageReview"]
    _object(review, f"{path}.replacement.coverageReview", COVERAGE_KEYS)
    expected = {
        "status": "approved",
        "legacyAddress": record["address"],
        "legacyName": record["name"],
        "legacyKind": record["kind"],
        "legacySubject": record.get("subject"),
        "legacyParameter": record.get("parameter"),
        "replacementAddress": replacement["address"],
        "replacementContractName": replacement["contractName"],
        "replacementSubjects": replacement["subjects"],
        "replacementParameters": replacement["parameters"],
    }
    for field, value in expected.items():
        actual = review[field]
        if field in {"legacyAddress", "replacementAddress"}:
            valid = isinstance(actual, str) and actual.lower() == value.lower()
        else:
            valid = actual == value
        _require(
            valid,
            f"{path}.replacement.coverageReview.{field}",
            "does not match the referenced record",
        )
    for field in ("evidence", "intendedCoverage"):
        _require(
            _nonempty(review[field]),
            f"{path}.replacement.coverageReview.{field}",
            "must be a nonempty string",
        )


def _validate_record(record, v2_by_address, path):
    _require(isinstance(record, dict), path, "must be an object")
    extra = record.keys() - RECORD_KEYS
    _require(not extra, path, f"unexpected fields: {', '.join(sorted(extra))}")
    for field in ("name", "kind", "owner", "ownerEvidence", "evidence"):
        _require(
            _nonempty(record.get(field)), f"{path}.{field}", "must be a nonempty string"
        )
    _require(
        _matches(record.get("address"), ADDRESS_RE),
        f"{path}.address",
        "must be an address",
    )
    snapshot_status = record.get("legacySnapshotStatus")
    migration_status = record.get("migrationStatus")
    if snapshot_status == "deprecated":
        _require(
            migration_status == "deprecated-v1",
            f"{path}.migrationStatus",
            "deprecated record must remain deprecated-v1",
        )
        for field in ("replacement", "retentionRationale", "revocationReason"):
            _require(
                field not in record,
                f"{path}.{field}",
                "is not allowed for deprecated record",
            )
        return
    _require(
        snapshot_status == "active",
        f"{path}.legacySnapshotStatus",
        "must be active or deprecated",
    )
    if migration_status == "waiting-for-reviewed-v2-replacement":
        forbidden = ("replacement", "retentionRationale", "revocationReason")
    elif migration_status == "revoked-v1":
        _require(
            _nonempty(record.get("revocationReason")),
            f"{path}.revocationReason",
            "must be a nonempty string",
        )
        forbidden = ("replacement", "retentionRationale")
    elif migration_status == "retained-v1-exception":
        _require(
            _nonempty(record.get("retentionRationale")),
            f"{path}.retentionRationale",
            "must be a nonempty string",
        )
        forbidden = ("replacement", "revocationReason")
    elif migration_status == "superseded-by-v2":
        forbidden = ("retentionRationale", "revocationReason")
        replacement_ref = record.get("replacement")
        _object(
            replacement_ref,
            f"{path}.replacement",
            {"address", "contractName", "coverageReview"},
        )
        _require(
            _matches(replacement_ref["address"], ADDRESS_RE),
            f"{path}.replacement.address",
            "must be an address",
        )
        _require(
            _nonempty(replacement_ref["contractName"]),
            f"{path}.replacement.contractName",
            "must be a nonempty string",
        )
        replacement = v2_by_address.get(replacement_ref["address"].lower())
        _require(
            replacement is not None,
            f"{path}.replacement.address",
            "is not published in the V2 manifest",
        )
        _require(
            replacement["operationalStatus"] == "incident-ready",
            f"{path}.replacement.address",
            "replacement is not incident-ready",
        )
        _require(
            replacement_ref["contractName"] == replacement["contractName"],
            f"{path}.replacement.contractName",
            "does not match V2 record",
        )
        _require(
            _replacement_allowed(record["name"], replacement, v2_by_address),
            f"{path}.replacement.contractName",
            "is not an allowed replacement family",
        )
        _validate_coverage(record, replacement, path)
    else:
        raise ValidationError(
            f"{path}.migrationStatus: invalid active migration status"
        )
    for field in forbidden:
        _require(
            field not in record,
            f"{path}.{field}",
            "is not allowed for this migration status",
        )


def validate_migration(legacy, v2, migration):
    v2_by_address = validate_manifest(v2)
    _object(
        migration,
        "migration",
        {
            "schemaVersion",
            "chainId",
            "architecture",
            "sourceSnapshot",
            "v2ManifestPath",
            "statusSemantics",
            "counts",
            "records",
        },
    )
    _require(migration["schemaVersion"] == 1, "migration.schemaVersion", "must be 1")
    _require(
        migration["chainId"] == legacy.get("chainId") == v2["chainId"],
        "migration.chainId",
        "must match both manifests",
    )
    _require(
        migration["architecture"] == "v1-to-v2-migration",
        "migration.architecture",
        "must be v1-to-v2-migration",
    )
    source = legacy.get("source", {})
    expected_source = {
        "path": "deployments/1/legacy-v1.json",
        "tag": source.get("tag"),
        "commit": source.get("commit"),
    }
    _require(
        migration["sourceSnapshot"] == expected_source,
        "migration.sourceSnapshot",
        "does not match legacy snapshot",
    )
    _require(
        migration["v2ManifestPath"] == "deployments/1/v2.json",
        "migration.v2ManifestPath",
        "must reference deployments/1/v2.json",
    )
    semantics = migration["statusSemantics"]
    _require(
        isinstance(semantics, dict) and set(semantics) == set(STATUSES),
        "migration.statusSemantics",
        "must define every migration status",
    )
    for status, description in semantics.items():
        _require(
            _nonempty(description),
            f"migration.statusSemantics.{status}",
            "must be a nonempty string",
        )
    records = migration["records"]
    _require(isinstance(records, list), "migration.records", "must be an array")
    expected = _expected_records(legacy)
    _require(
        [_identity(record) for record in records]
        == [_identity(record) for record in expected],
        "migration.records",
        "must preserve legacy record identity and order",
    )
    addresses = [record.get("address", "").lower() for record in records]
    _require(
        len(addresses) == len(set(addresses)),
        "migration.records",
        "contains duplicate addresses",
    )
    counts = {field: 0 for field in STATUSES.values()}
    for index, record in enumerate(records):
        _validate_record(record, v2_by_address, f"records[{index}]")
        counts[STATUSES[record["migrationStatus"]]] += 1
    counts["total"] = len(records)
    _require(
        migration["counts"] == counts,
        "migration.counts",
        "does not match record statuses",
    )
    return records
