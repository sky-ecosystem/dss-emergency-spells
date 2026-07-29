import json
import unittest
from pathlib import Path

from .common import ValidationError
from .draft import draft_batch, draft_deployment
from .common.manifest import validate_manifest


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / "deployments/v2.schema.json").read_text())
SOURCE_COMMIT = "1" * 40
TRANSACTION_HASH = "0x" + "22" * 32
ADDRESS = "0x0000000000000000000000000000000000000011"
FACTORY = "0x00000000000000000000000000000000000000f1"
BATCH = "0x00000000000000000000000000000000000000b1"
BATCH_TRANSACTION_HASH = "0x" + "99" * 32
LEAF1 = "0x0000000000000000000000000000000000000011"
LEAF2 = "0x0000000000000000000000000000000000000022"
CONFIG_HASH = "0x66fbf5b80224f0df35fa2a524c580bc83ea780a0e2e0dda40366cf190f725300"
EVENT_SIGNATURE = "0xb20dab77fc2616d68d46577b9b7f8ac73dfd05bfdc661bcd0db909ee488f1e30"


class DirectDraftRunner:
    def __init__(self):
        self.creation_code = "0x6000"
        self.transaction = {"to": None, "input": "0x60001234"}
        self.receipt = {
            "status": "0x1",
            "transactionHash": TRANSACTION_HASH,
            "blockNumber": "0x2a",
            "contractAddress": ADDRESS,
        }
        self.codehash = "0x" + "ab" * 32
        self.readbacks = {
            "action()(address)": ADDRESS,
            "pause()(address)": "0x0000000000000000000000000000000000000012",
            "lineMom()(address)": "0x0000000000000000000000000000000000000021",
            "ilk()(bytes32)": "0x" + "45" * 32,
            "autoLine()(address)": "0x0000000000000000000000000000000000000022",
            "vat()(address)": "0x0000000000000000000000000000000000000023",
            "flow()(uint8)": "2",
        }
        self.failures = set()

    def run(self, tool, *arguments):
        command = arguments[0]
        if (tool, command) in self.failures:
            raise ValidationError(f"{tool} failed: test failure")
        if tool == "git":
            return {
                "rev-parse": SOURCE_COMMIT,
                "status": "",
                "verify-commit": "",
                "diff": "",
            }[command]
        if tool == "forge":
            return self.creation_code
        if command == "tx":
            return json.dumps(self.transaction)
        if command == "receipt":
            return json.dumps(self.receipt)
        if command == "codehash":
            return self.codehash
        if command == "call":
            return self.readbacks[arguments[2]]
        raise AssertionError((tool, arguments))


class DirectDraftTests(unittest.TestCase):
    def draft(self, runner=None, **overrides):
        arguments = {
            "artifact": "src/line-wipe/LineWipeSpellV2.sol:LineWipeSpellV2",
            "kind": "leaf",
            "transaction_hash": TRANSACTION_HASH,
            "subjects": ["lineMom()(address)", "ilk()(bytes32)"],
            "parameters": [],
            "immutable_readbacks": ["autoLine()(address)", "vat()(address)"],
            "rpc_url": "mock://",
            "runner": runner or DirectDraftRunner(),
            "root": ROOT,
        }
        arguments.update(overrides)
        return draft_deployment(**arguments)

    def test_generates_schema_named_leaf_record(self):
        record = self.draft(parameters=["flow()(uint8)"])

        self.assertEqual(set(record), set(SCHEMA["$defs"]["record"]["required"]))
        self.assertEqual(
            set(record["deployment"]),
            set(SCHEMA["$defs"]["deployment"]["required"]),
        )
        self.assertEqual(set(record["reviews"]), {"directUse", "batchUse"})
        self.assertEqual(record["contractName"], "LineWipeSpellV2")
        self.assertEqual(record["address"], ADDRESS)
        self.assertEqual(record["sourceCommit"], SOURCE_COMMIT)
        self.assertEqual(record["deployment"]["transactionHash"], TRANSACTION_HASH)
        self.assertEqual(record["deployment"]["blockNumber"], 42)
        self.assertEqual(record["deployment"]["constructorArguments"], "0x1234")
        self.assertEqual(record["parameters"], {"flow()(uint8)": "2"})
        self.assertEqual(
            list(record["immutableReadbacks"]),
            [
                "action()(address)",
                "autoLine()(address)",
                "flow()(uint8)",
                "ilk()(bytes32)",
                "lineMom()(address)",
                "pause()(address)",
                "vat()(address)",
            ],
        )
        self.assertEqual(
            record["reviews"]["directUse"], {"status": "pending", "evidence": ""}
        )
        self.assertEqual(
            record["reviews"]["batchUse"], {"status": "pending", "evidence": ""}
        )
        self.assertFalse(record["batchEligible"])
        self.assertEqual(record["operationalStatus"], "deployed")

    def test_generated_record_is_invalid_until_review_evidence_is_added(self):
        record = self.draft()
        manifest = {
            "schemaVersion": 2,
            "chainId": 1,
            "architecture": "emergency-spells-v2",
            "records": [record],
        }
        with self.assertRaisesRegex(ValidationError, "evidence"):
            validate_manifest(manifest)

    def test_infrastructure_does_not_add_spell_readbacks(self):
        runner = DirectDraftRunner()
        runner.transaction["input"] = runner.creation_code
        record = self.draft(
            runner,
            artifact="src/EmergencySpellBatchFactoryV2.sol:EmergencySpellBatchFactoryV2",
            kind="infrastructure",
            subjects=[],
            immutable_readbacks=[],
        )
        self.assertEqual(record["immutableReadbacks"], {})
        self.assertEqual(record["deployment"]["constructorArguments"], "0x")
        self.assertEqual(record["reviews"]["batchUse"]["status"], "not-applicable")

    def test_rejects_missing_subjects_for_spells(self):
        with self.assertRaisesRegex(ValidationError, "subjects"):
            self.draft(subjects=[])

    def test_rejects_invalid_artifact_transaction_and_receipt(self):
        with self.assertRaisesRegex(ValidationError, "artifact"):
            self.draft(artifact="wrong:Contract")

        runner = DirectDraftRunner()
        runner.transaction["to"] = ADDRESS
        with self.assertRaisesRegex(ValidationError, "direct CREATE"):
            self.draft(runner)

        runner = DirectDraftRunner()
        runner.transaction["input"] = "0x9999"
        with self.assertRaisesRegex(ValidationError, "creation bytecode"):
            self.draft(runner)

        runner = DirectDraftRunner()
        runner.receipt["status"] = "0x0"
        with self.assertRaisesRegex(ValidationError, "transaction failed"):
            self.draft(runner)


class BatchDraftRunner:
    def __init__(self):
        self.batch_calldata = "0xdeadbeef"
        self.event_factory = FACTORY
        self.predicted = BATCH
        self.event_mode = 1
        self.leaf_codehash = "0x" + "11" * 32
        self.readback_leaves = [LEAF1, LEAF2]

    def run(self, tool, *arguments):
        command = arguments[0]
        if tool == "git":
            return {
                "rev-parse": "2" * 40,
                "status": "",
                "verify-commit": "",
                "diff": "",
            }[command]
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
                EVENT_SIGNATURE
                if arguments[1] == "BatchDeployed(address,bytes32)"
                else CONFIG_HASH
            )
        if command == "calldata":
            return "0xdeadbeef"
        if command == "codehash":
            return {
                FACTORY.lower(): "0x" + "f1" * 32,
                BATCH.lower(): "0x" + "bb" * 32,
                LEAF1.lower(): self.leaf_codehash,
                LEAF2.lower(): "0x" + "22" * 32,
            }[arguments[1].lower()]
        if command == "call":
            address, signature = arguments[1], arguments[2]
            if address.lower() == FACTORY.lower():
                raise AssertionError((tool, arguments))
            return {
                "label()(string)": '"Incident batch"',
                "leaves()(address[])": f"[{', '.join(self.readback_leaves)}]",
                "configHash()(bytes32)": CONFIG_HASH,
                "action()(address)": BATCH,
                "pause()(address)": "0x0000000000000000000000000000000000000012",
            }[signature]
        if command == "tx":
            if arguments[1] == "0x" + "ff" * 32:
                return json.dumps({"to": None, "input": "0x6000"})
            return json.dumps({"to": FACTORY, "input": self.batch_calldata})
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
            return json.dumps(
                {
                    "status": "0x1",
                    "transactionHash": BATCH_TRANSACTION_HASH,
                    "blockNumber": "0x4",
                    "contractAddress": None,
                    "logs": [
                        {
                            "address": self.event_factory,
                            "topics": [
                                EVENT_SIGNATURE,
                                "0x" + "0" * 24 + BATCH[2:],
                                CONFIG_HASH,
                            ],
                            "data": "0x",
                        }
                    ],
                }
            )
        raise AssertionError((tool, arguments))


class BatchDraftTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(
            (ROOT / "cli/fixtures/v2-manifest-valid.json").read_text()
        )

    def draft(self, runner=None, **overrides):
        arguments = {
            "manifest": self.manifest,
            "factory_address": FACTORY,
            "transaction_hash": BATCH_TRANSACTION_HASH,
            "label": "Incident batch",
            "leaves": [LEAF1, LEAF2],
            "rpc_url": "mock://",
            "runner": runner or BatchDraftRunner(),
            "root": ROOT,
        }
        arguments.update(overrides)
        return draft_batch(**arguments)

    def test_generates_schema_named_batch_record(self):
        record = self.draft()

        expected_record_keys = set(SCHEMA["$defs"]["record"]["required"]) | {"batch"}
        self.assertEqual(set(record), expected_record_keys)
        self.assertEqual(
            set(record["batch"]), set(SCHEMA["$defs"]["batch"]["required"])
        )
        self.assertEqual(
            set(record["batch"]["atomicSimulation"]),
            set(SCHEMA["$defs"]["simulation"]["required"]),
        )
        self.assertEqual(record["contractName"], "EmergencySpellBatchV2")
        self.assertEqual(record["address"], BATCH)
        self.assertEqual(record["sourceCommit"], SOURCE_COMMIT)
        self.assertEqual(record["deployment"]["constructorArguments"], "0xabcdef")
        self.assertEqual(record["batch"]["leaves"], [LEAF1, LEAF2])
        self.assertNotIn("deploymentMode", record["batch"])
        self.assertEqual(record["batch"]["configHash"], CONFIG_HASH)
        self.assertTrue(record["batch"]["factoryEventVerified"])
        self.assertEqual(record["batch"]["atomicSimulation"]["reference"], "")

    def test_generated_batch_is_invalid_until_review_and_simulation_are_added(self):
        record = self.draft()
        manifest = {
            "schemaVersion": 2,
            "chainId": 1,
            "architecture": "emergency-spells-v2",
            "records": [
                next(
                    record
                    for record in self.manifest["records"]
                    if record["address"].lower() == FACTORY.lower()
                ),
                *[
                    record
                    for record in self.manifest["records"]
                    if record["address"].lower() in {LEAF1.lower(), LEAF2.lower()}
                ],
                record,
            ],
        }
        with self.assertRaises(ValidationError):
            validate_manifest(manifest)

    def test_preserves_arbitrary_unique_order(self):
        runner = BatchDraftRunner()
        runner.event_mode = 0
        runner.predicted = "not-used"
        runner.readback_leaves = [LEAF2, LEAF1]

        record = self.draft(
            runner,
            leaves=[LEAF2, LEAF1],
        )

        self.assertEqual(record["batch"]["leaves"], [LEAF2, LEAF1])

    def test_rejects_wrong_factory_call_event_and_leaf_codehash(self):
        runner = BatchDraftRunner()
        runner.batch_calldata = "0xfeedface"
        with self.assertRaisesRegex(ValidationError, "calldata"):
            self.draft(runner)

        runner = BatchDraftRunner()
        runner.event_factory = "0x00000000000000000000000000000000000000f2"
        with self.assertRaisesRegex(ValidationError, "BatchDeployed"):
            self.draft(runner)

        runner = BatchDraftRunner()
        runner.leaf_codehash = "0x" + "ff" * 32
        with self.assertRaisesRegex(ValidationError, "runtime codehash"):
            self.draft(runner)


if __name__ == "__main__":
    unittest.main()
