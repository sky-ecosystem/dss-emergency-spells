import copy
import json
import unittest
from pathlib import Path

from .batch import preflight_batch, verify_batch
from .common import ValidationError


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = json.loads((ROOT / "cli/fixtures/v2-manifest-valid.json").read_text())
LEAF1 = "0x0000000000000000000000000000000000000011"
LEAF2 = "0x0000000000000000000000000000000000000022"
GLOBAL = "0x0000000000000000000000000000000000000031"
FACTORY = "0x00000000000000000000000000000000000000f1"
BATCH = "0x00000000000000000000000000000000000000b1"
TX = "0x" + "99" * 32
CONFIG = "0x66fbf5b80224f0df35fa2a524c580bc83ea780a0e2e0dda40366cf190f725300"
EVENT = "0xb20dab77fc2616d68d46577b9b7f8ac73dfd05bfdc661bcd0db909ee488f1e30"


class FakeRunner:
    def __init__(self):
        self.broken_factory_call = False
        self.broken_event = False

    def run(self, tool, *arguments):
        command = arguments[0]
        if tool == "git":
            return {"rev-parse": "1" * 40, "status": "", "verify-commit": ""}[command]
        if tool == "forge":
            return (
                "0x6000"
                if "EmergencySpellBatchFactoryV2" in arguments[-2]
                else "0x7000"
            )
        if command == "chain-id":
            return "1"
        if command == "abi-encode":
            return "0xabcdef"
        if command == "keccak":
            return (
                EVENT
                if arguments[1] == "BatchDeployed(address,bytes32,uint8)"
                else CONFIG
            )
        if command == "calldata":
            return "0xdeadbeef"
        if command == "create2":
            return BATCH
        if command == "codehash":
            return {
                LEAF1.lower(): "0x" + "11" * 32,
                LEAF2.lower(): "0x" + "22" * 32,
                FACTORY.lower(): "0x" + "f1" * 32,
                BATCH.lower(): "0x" + "bb" * 32,
            }[arguments[1].lower()]
        if command == "call":
            signature = arguments[2]
            if signature == "previewDeterministicAddress(address[],string)(address)":
                return BATCH
            return {
                "label()(string)": '"Incident batch"',
                "leaves()(address[])": f"[{LEAF1}, {LEAF2}]",
                "configHash()(bytes32)": CONFIG,
                "action()(address)": BATCH,
                "pause()(address)": "0x0000000000000000000000000000000000000012",
            }[signature]
        if command == "tx":
            if arguments[1] == "0x" + "ff" * 32:
                return json.dumps({"to": None, "input": "0x6000"})
            calldata = "0xfeedface" if self.broken_factory_call else "0xdeadbeef"
            return json.dumps({"to": FACTORY, "input": calldata})
        if command == "receipt":
            if arguments[1] == "0x" + "ff" * 32:
                return json.dumps(
                    {
                        "status": "0x1",
                        "transactionHash": "0x" + "ff" * 32,
                        "blockNumber": "0x1",
                        "contractAddress": FACTORY,
                    }
                )
            emitter = (
                "0x00000000000000000000000000000000000000f2"
                if self.broken_event
                else FACTORY
            )
            return json.dumps(
                {
                    "status": "0x1",
                    "transactionHash": TX,
                    "blockNumber": "0x4",
                    "contractAddress": None,
                    "logs": [
                        {
                            "address": emitter,
                            "topics": [EVENT, "0x" + "0" * 24 + BATCH[2:], CONFIG],
                            "data": "0x" + "0" * 63 + "1",
                        }
                    ],
                }
            )
        raise AssertionError((tool, arguments))


class BatchPreflightTests(unittest.TestCase):
    def test_accepts_create_order_and_predicts_create2(self):
        create = preflight_batch(
            MANIFEST,
            FACTORY,
            "create",
            "Incident batch",
            [LEAF2, LEAF1],
            "mock://",
            FakeRunner(),
            ROOT,
        )
        self.assertEqual(create, {"configHash": CONFIG})
        create2 = preflight_batch(
            MANIFEST,
            FACTORY,
            "create2",
            "Incident batch",
            [LEAF1, LEAF2],
            "mock://",
            FakeRunner(),
            ROOT,
        )
        self.assertEqual(create2, {"configHash": CONFIG, "predictedBatch": BATCH})

    def test_rejects_bad_selection(self):
        cases = (
            ("create2", "Incident batch", [LEAF2, LEAF1]),
            ("create", "Incident batch", [GLOBAL]),
            ("create", "", [LEAF1]),
            ("create", "Incident batch", [LEAF1, LEAF1]),
        )
        for mode, label, leaves in cases:
            with self.assertRaises(ValidationError):
                preflight_batch(
                    MANIFEST,
                    FACTORY,
                    mode,
                    label,
                    leaves,
                    "mock://",
                    FakeRunner(),
                    ROOT,
                )


class BatchVerificationTests(unittest.TestCase):
    def verify(self, manifest=MANIFEST, runner=None, label="Incident batch"):
        return verify_batch(
            manifest,
            BATCH,
            FACTORY,
            TX,
            "create2",
            label,
            [LEAF1, LEAF2],
            "mock://",
            runner or FakeRunner(),
            ROOT,
        )

    def test_verifies_batch(self):
        self.verify()

    def test_rejects_manifest_factory_call_and_event_mismatch(self):
        with self.assertRaises(ValidationError):
            self.verify(label="Wrong label")
        runner = FakeRunner()
        runner.broken_factory_call = True
        with self.assertRaises(ValidationError):
            self.verify(runner=runner)
        runner = FakeRunner()
        runner.broken_event = True
        with self.assertRaises(ValidationError):
            self.verify(runner=runner)

    def test_preserves_revoked_history_verification(self):
        manifest = copy.deepcopy(MANIFEST)
        for record in manifest["records"]:
            if record["kind"] in {"infrastructure", "batch", "leaf"}:
                record["operationalStatus"] = "revoked"
        self.verify(manifest=manifest)


if __name__ == "__main__":
    unittest.main()
