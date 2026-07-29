import json
import unittest
from pathlib import Path

from .common import ValidationError
from .migration import validate_migration


ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def inputs():
    return (
        load("deployments/1/legacy-v1.json"),
        load("deployments/1/v2.json"),
        load("deployments/1/v1-migration.json"),
    )


def superseded(migration):
    record = migration["records"][0]
    record["migrationStatus"] = "superseded-by-v2"
    record["replacement"] = {
        "address": "0x0000000000000000000000000000000000000044",
        "contractName": "SPBEAMHaltSpellV2",
        "coverageReview": {
            "status": "approved",
            "evidence": "https://example.com/spbeam-equivalence-review",
            "legacyAddress": record["address"],
            "legacyName": record["name"],
            "legacyKind": record["kind"],
            "legacySubject": None,
            "legacyParameter": None,
            "replacementAddress": "0x0000000000000000000000000000000000000044",
            "replacementContractName": "SPBEAMHaltSpellV2",
            "replacementSubjects": {
                "spbeam()(address)": "0x0000000000000000000000000000000000000046",
                "spbeamMom()(address)": "0x0000000000000000000000000000000000000045",
            },
            "replacementParameters": {},
            "intendedCoverage": "Halt the canonical SPBEAM instance through its emergency mom.",
        },
    }
    record["evidence"] = "Reviewed equivalent incident-ready V2 replacement."
    migration["counts"]["waitingForReviewedV2Replacement"] -= 1
    migration["counts"]["supersededByV2"] += 1


class MigrationTests(unittest.TestCase):
    def assert_invalid(self, legacy, v2, migration):
        with self.assertRaises(ValidationError):
            validate_migration(legacy, v2, migration)

    def test_accepts_canonical_migration(self):
        validate_migration(*inputs())

    def test_requires_exact_legacy_identity_and_counts(self):
        for mutation in (
            lambda data: data["records"].pop(0),
            lambda data: data["records"][0].update(name="WrongSpell"),
            lambda data: data["counts"].update(total=73),
        ):
            legacy, v2, migration = inputs()
            mutation(migration)
            self.assert_invalid(legacy, v2, migration)

    def test_requires_owner_and_evidence(self):
        for field in ("owner", "ownerEvidence", "evidence"):
            legacy, v2, migration = inputs()
            migration["records"][0][field] = ""
            self.assert_invalid(legacy, v2, migration)

    def test_validates_active_status_variants(self):
        legacy, v2, migration = inputs()
        record = migration["records"][0]
        record["migrationStatus"] = "revoked-v1"
        record["revocationReason"] = "Withdrawn after failed incident validation."
        migration["counts"]["waitingForReviewedV2Replacement"] -= 1
        migration["counts"]["revokedV1"] += 1
        validate_migration(legacy, v2, migration)
        del record["revocationReason"]
        self.assert_invalid(legacy, v2, migration)

        legacy, v2, migration = inputs()
        record = migration["records"][0]
        record["migrationStatus"] = "retained-v1-exception"
        record["retentionRationale"] = "Reviewed legacy exception."
        migration["counts"]["waitingForReviewedV2Replacement"] -= 1
        migration["counts"]["retainedV1Exception"] += 1
        validate_migration(legacy, v2, migration)
        del record["retentionRationale"]
        self.assert_invalid(legacy, v2, migration)

    def test_rejects_invalid_v2_before_migration(self):
        legacy, _, migration = inputs()
        v2 = load("cli/fixtures/v2-manifest-valid.json")
        v2["records"][0]["artifact"] = "src/osm-stop/OsmStopSpellV2.sol:OsmStopSpellV2"
        self.assert_invalid(legacy, v2, migration)

    def test_accepts_exact_reviewed_replacement(self):
        legacy, _, migration = inputs()
        v2 = load("cli/fixtures/v2-manifest-valid.json")
        superseded(migration)
        validate_migration(legacy, v2, migration)

    def test_rejects_unpublished_or_wrong_replacement(self):
        legacy, v2, migration = inputs()
        superseded(migration)
        self.assert_invalid(legacy, v2, migration)

        legacy, _v2, migration = inputs()
        v2 = load("cli/fixtures/v2-manifest-valid.json")
        superseded(migration)
        replacement = migration["records"][0]["replacement"]
        replacement["address"] = "0x0000000000000000000000000000000000000011"
        replacement["contractName"] = "LineWipeSpellV2"
        replacement["coverageReview"]["replacementAddress"] = replacement["address"]
        replacement["coverageReview"]["replacementContractName"] = replacement[
            "contractName"
        ]
        self.assert_invalid(legacy, v2, migration)

    def test_binds_coverage_review_to_both_records(self):
        mutations = (
            lambda review: review.update(
                legacyAddress="0x0000000000000000000000000000000000000001"
            ),
            lambda review: review.update(legacySubject="ETH-A", legacyParameter="BUY"),
            lambda review: review["replacementSubjects"].update(
                {"spbeam()(address)": "0x0000000000000000000000000000000000000001"}
            ),
        )
        for mutation in mutations:
            legacy, _v2, migration = inputs()
            v2 = load("cli/fixtures/v2-manifest-valid.json")
            superseded(migration)
            mutation(migration["records"][0]["replacement"]["coverageReview"])
            self.assert_invalid(legacy, v2, migration)


if __name__ == "__main__":
    unittest.main()
