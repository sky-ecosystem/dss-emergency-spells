import copy
import json
import unittest
from pathlib import Path

from .manifest import validate_manifest
from .validation import ValidationError


ROOT = Path(__file__).resolve().parents[3]


def fixture(name="v2-manifest-valid.json"):
    return json.loads((ROOT / "cli" / "fixtures" / name).read_text())


class ManifestTests(unittest.TestCase):
    def assert_invalid(self, data):
        with self.assertRaises(ValidationError):
            validate_manifest(data)

    def test_accepts_canonical_manifests(self):
        validate_manifest(json.loads((ROOT / "deployments/1/v2.json").read_text()))
        validate_manifest(fixture())

    def test_rejects_invalid_global(self):
        self.assert_invalid(fixture("v2-manifest-invalid-global.json"))

    def test_accepts_new_spell_without_validator_changes(self):
        data = fixture()
        record = copy.deepcopy(data["records"][0])
        record["contractName"] = "NewEmergencySpellV2"
        record["artifact"] = (
            "src/new-emergency/NewEmergencySpellV2.sol:NewEmergencySpellV2"
        )
        record["address"] = "0x0000000000000000000000000000000000000099"
        record["immutableReadbacks"] = {
            "action()(address)": record["address"],
            "pause()(address)": "0x0000000000000000000000000000000000000012",
            "subject()(address)": "0x0000000000000000000000000000000000000098",
            "mode()(uint8)": "1",
        }
        record["subjects"] = {
            "subject()(address)": record["immutableReadbacks"]["subject()(address)"]
        }
        record["parameters"] = {"mode()(uint8)": "1"}
        data["records"].append(record)
        validate_manifest(data)

    def test_rejects_invalid_record_fields_and_review_state(self):
        cases = []

        data = fixture()
        data["records"][0]["reviews"]["directUse"]["status"] = "rejected"
        cases.append(data)

        data = fixture()
        del data["records"][0]["immutableReadbacks"]["action()(address)"]
        cases.append(data)

        data = fixture()
        data["records"][0]["artifact"] = (
            "src/osm-stop/OsmStopSpellV2.sol:OsmStopSpellV2"
        )
        cases.append(data)

        data = fixture()
        data["records"][0]["subjects"]["ilk()(bytes32)"] = "0x" + "57" * 32
        cases.append(data)

        for data in cases:
            with self.subTest(data=data):
                self.assert_invalid(data)

    def test_rejects_invalid_batch_readbacks_and_simulation(self):
        data = fixture()
        batch = next(record for record in data["records"] if record["kind"] == "batch")
        batch["batch"]["atomicSimulation"]["status"] = "pending"
        self.assert_invalid(data)

    def test_rejects_obsolete_batch_deployment_mode(self):
        data = fixture()
        batch = next(record for record in data["records"] if record["kind"] == "batch")
        batch["batch"]["deploymentMode"] = "create"
        self.assert_invalid(data)

        data = fixture()
        batch = next(record for record in data["records"] if record["kind"] == "batch")
        batch["batch"]["getterReadbacks"]["label"] = "Wrong label"
        self.assert_invalid(data)

    def test_requires_batch_dependencies_and_deployment_order(self):
        mutations = [
            lambda data: data.update(
                records=[r for r in data["records"] if r["kind"] != "infrastructure"]
            ),
            lambda data: next(
                r for r in data["records"] if r["kind"] == "infrastructure"
            )["deployment"].update(blockNumber=5),
            lambda data: data["records"][0]["deployment"].update(blockNumber=5),
            lambda data: data.update(
                records=[
                    r
                    for r in data["records"]
                    if r["address"].lower()
                    != "0x0000000000000000000000000000000000000011"
                ]
            ),
        ]
        for mutation in mutations:
            data = fixture()
            mutation(data)
            self.assert_invalid(data)

    def test_ready_batch_requires_ready_factory_and_leaves(self):
        data = fixture()
        data["records"][0]["operationalStatus"] = "revoked"
        self.assert_invalid(data)

        data = fixture()
        next(r for r in data["records"] if r["kind"] == "infrastructure")[
            "operationalStatus"
        ] = "revoked"
        self.assert_invalid(data)

    def test_preserves_revoked_batch_history(self):
        for kind in ("leaf", "infrastructure"):
            data = fixture()
            next(r for r in data["records"] if r["kind"] == kind)[
                "operationalStatus"
            ] = "revoked"
            next(r for r in data["records"] if r["kind"] == "batch")[
                "operationalStatus"
            ] = "revoked"
            validate_manifest(data)


if __name__ == "__main__":
    unittest.main()
