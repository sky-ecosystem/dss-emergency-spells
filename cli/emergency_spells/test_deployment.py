import json
import unittest
from pathlib import Path

from .common import ValidationError
from .deployment import verify_deployment


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = json.loads((ROOT / "cli/fixtures/v2-manifest-valid.json").read_text())
SPELL = "0x0000000000000000000000000000000000000011"
TX = "0x" + "22" * 32


class FakeRunner:
    def __init__(self):
        self.values = {
            ("cast", "chain-id"): "1",
            ("git", "rev-parse"): "1" * 40,
            ("git", "status"): "",
            ("git", "verify-commit"): "",
            ("forge", "inspect"): "0x6000",
            ("cast", "tx"): json.dumps({"to": None, "input": "0x60001234"}),
            ("cast", "codehash"): "0x" + "11" * 32,
            ("cast", "receipt"): json.dumps(
                {
                    "status": "0x1",
                    "transactionHash": TX,
                    "blockNumber": "0x1",
                    "contractAddress": SPELL,
                }
            ),
        }
        self.readbacks = MANIFEST["records"][0]["immutableReadbacks"]

    def run(self, tool, *arguments):
        if tool == "cast" and arguments[0] == "call":
            return self.readbacks[arguments[2]]
        return self.values[(tool, arguments[0])]


class DeploymentTests(unittest.TestCase):
    def assert_invalid(self, runner, address=SPELL):
        with self.assertRaises(ValidationError):
            verify_deployment(MANIFEST, address, "mock://", runner, ROOT)

    def test_verifies_direct_deployment(self):
        verify_deployment(MANIFEST, SPELL, "mock://", FakeRunner(), ROOT)

    def test_requires_published_non_batch_address(self):
        self.assert_invalid(FakeRunner(), "0x0000000000000000000000000000000000000099")
        self.assert_invalid(FakeRunner(), "0x00000000000000000000000000000000000000b1")

    def test_requires_exact_clean_signed_source(self):
        for key, value in (
            (("git", "rev-parse"), "2" * 40),
            (("git", "status"), "?? remappings.txt"),
        ):
            runner = FakeRunner()
            runner.values[key] = value
            self.assert_invalid(runner)

    def test_requires_exact_initcode_and_runtime(self):
        runner = FakeRunner()
        runner.values[("cast", "tx")] = json.dumps({"to": None, "input": "0x600099"})
        self.assert_invalid(runner)

        runner = FakeRunner()
        runner.values[("cast", "codehash")] = "0x" + "ff" * 32
        self.assert_invalid(runner)

    def test_requires_immutable_readbacks(self):
        runner = FakeRunner()
        runner.readbacks = dict(
            runner.readbacks,
            **{"vat()(address)": "0x0000000000000000000000000000000000000099"},
        )
        self.assert_invalid(runner)

    def test_requires_matching_successful_receipt(self):
        mutations = (
            {"status": "0x0"},
            {"contractAddress": "0x0000000000000000000000000000000000000099"},
            {"transactionHash": "0x" + "99" * 32},
            {"blockNumber": "0x5"},
        )
        for mutation in mutations:
            runner = FakeRunner()
            receipt = json.loads(runner.values[("cast", "receipt")])
            receipt.update(mutation)
            runner.values[("cast", "receipt")] = json.dumps(receipt)
            self.assert_invalid(runner)


if __name__ == "__main__":
    unittest.main()
