import io
import json
import os
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

from .cli import _parser, main


ROOT = Path(__file__).resolve().parents[2]


class CliTests(unittest.TestCase):
    def run_cli(self, arguments):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            code = main(arguments)
        return code, stdout.getvalue(), stderr.getvalue()

    def test_validates_manifest_and_migration_with_named_flags(self):
        code, output, _ = self.run_cli(
            ["validate-manifest", "--manifest", str(ROOT / "deployments/1/v2.json")]
        )
        self.assertEqual(code, 0)
        self.assertIn("Validated V2 manifest", output)

        code, output, _ = self.run_cli(
            [
                "validate-migration",
                "--legacy",
                str(ROOT / "deployments/1/legacy-v1.json"),
                "--v2-manifest",
                str(ROOT / "deployments/1/v2.json"),
                "--migration",
                str(ROOT / "deployments/1/v1-migration.json"),
            ]
        )
        self.assertEqual(code, 0)
        self.assertIn("Validated V1 migration", output)

    def test_schema_aligned_flags_and_readable_aliases_are_equivalent(self):
        parser = _parser()
        canonical = parser.parse_args(
            [
                "verify-batch",
                "--manifest",
                "manifest.json",
                "--batch",
                "0xbatch",
                "--factory",
                "0xfactory",
                "--transaction-hash",
                "0xtx",
                "--label",
                "Incident batch",
                "--leaves",
                "[0x1,0x2]",
            ]
        )
        aliases = parser.parse_args(
            [
                "verify-batch",
                "--manifest",
                "manifest.json",
                "--batch",
                "0xbatch",
                "--factory",
                "0xfactory",
                "--tx",
                "0xtx",
                "--label",
                "Incident batch",
                "--leaves",
                "[0x1,0x2]",
            ]
        )
        self.assertEqual(vars(canonical), vars(aliases))

        canonical = parser.parse_args(
            [
                "draft-batch",
                "--manifest",
                "manifest.json",
                "--factory",
                "0xfactory",
                "--transaction-hash",
                "0xtx",
                "--label",
                "Incident batch",
                "--leaves",
                "[0x1,0x2]",
            ]
        )
        aliases = parser.parse_args(
            [
                "draft-batch",
                "--manifest",
                "manifest.json",
                "--factory",
                "0xfactory",
                "--tx",
                "0xtx",
                "--label",
                "Incident batch",
                "--leaves",
                "[0x1,0x2]",
            ]
        )
        self.assertEqual(vars(canonical), vars(aliases))
        self.assertEqual(canonical.transaction_hash, "0xtx")
        self.assertEqual(canonical.leaves, "[0x1,0x2]")

        canonical = parser.parse_args(
            [
                "draft-deployment",
                "--artifact",
                "src/Test.sol:Test",
                "--kind",
                "leaf",
                "--transaction-hash",
                "0xtx",
                "--subjects",
                '["subject()(address)"]',
                "--parameters",
                '["parameter()(uint8)"]',
                "--immutable-readbacks",
                '["dependency()(address)"]',
            ]
        )
        aliases = parser.parse_args(
            [
                "draft-deployment",
                "--artifact",
                "src/Test.sol:Test",
                "--kind",
                "leaf",
                "--tx",
                "0xtx",
                "--subjects",
                '["subject()(address)"]',
                "--params",
                '["parameter()(uint8)"]',
                "--readbacks",
                '["dependency()(address)"]',
            ]
        )
        self.assertEqual(vars(canonical), vars(aliases))

        canonical = parser.parse_args(
            [
                "validate-migration",
                "--legacy",
                "legacy.json",
                "--v2-manifest",
                "v2.json",
                "--migration",
                "migration.json",
            ]
        )
        aliases = parser.parse_args(
            [
                "validate-migration",
                "--legacy",
                "legacy.json",
                "--v2",
                "v2.json",
                "--mig",
                "migration.json",
            ]
        )
        self.assertEqual(vars(canonical), vars(aliases))

    @patch("cli.emergency_spells.cli.draft_deployment")
    def test_prints_direct_deployment_draft_as_json_only(self, draft):
        draft.return_value = {"contractName": "Test", "operationalStatus": "deployed"}
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, error = self.run_cli(
                [
                    "draft-deployment",
                    "--artifact",
                    "src/Test.sol:Test",
                    "--kind",
                    "leaf",
                    "--tx",
                    "0x" + "11" * 32,
                    "--subjects",
                    '["subject()(address)"]',
                    "--params",
                    "[]",
                    "--readbacks",
                    '["dependency()(address)"]',
                ]
            )
        self.assertEqual(code, 0)
        self.assertEqual(error, "")
        self.assertEqual(json.loads(output), draft.return_value)
        self.assertEqual(draft.call_args.kwargs["subjects"], ["subject()(address)"])
        self.assertEqual(draft.call_args.kwargs["parameters"], [])
        self.assertEqual(
            draft.call_args.kwargs["immutable_readbacks"],
            ["dependency()(address)"],
        )

    @patch("cli.emergency_spells.cli.draft_batch")
    def test_prints_batch_draft_as_json_only(self, draft):
        draft.return_value = {
            "contractName": "EmergencySpellBatchV2",
            "operationalStatus": "deployed",
        }
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, error = self.run_cli(
                [
                    "draft-batch",
                    "--manifest",
                    str(ROOT / "cli/fixtures/v2-manifest-valid.json"),
                    "--factory",
                    "0x00000000000000000000000000000000000000f1",
                    "--tx",
                    "0x" + "11" * 32,
                    "--label",
                    "Incident batch",
                    "--leaves",
                    "[0x0000000000000000000000000000000000000011,0x0000000000000000000000000000000000000022]",
                ]
            )
        self.assertEqual(code, 0)
        self.assertEqual(error, "")
        self.assertEqual(json.loads(output), draft.return_value)
        self.assertEqual(
            draft.call_args.kwargs["leaves"],
            [
                "0x0000000000000000000000000000000000000011",
                "0x0000000000000000000000000000000000000022",
            ],
        )

    def test_live_commands_require_eth_rpc_url(self):
        with patch.dict(os.environ, {}, clear=True):
            code, _, error = self.run_cli(
                [
                    "verify-deployment",
                    "--manifest",
                    str(ROOT / "deployments/1/v2.json"),
                    "--address",
                    "0x0000000000000000000000000000000000000001",
                ]
            )
        self.assertEqual(code, 2)
        self.assertIn("ETH_RPC_URL", error)

        with patch.dict(os.environ, {}, clear=True):
            code, _, error = self.run_cli(
                [
                    "probe-registry",
                    "--spell",
                    "0x0000000000000000000000000000000000000011",
                ]
            )
        self.assertEqual(code, 2)
        self.assertIn("ETH_RPC_URL", error)

    @patch("cli.emergency_spells.cli.probe_registry")
    def test_renders_complete_registry_probe_and_exits_one(self, probe):
        probe.return_value = {
            "spell": "0x0000000000000000000000000000000000000011",
            "registry": "0x0000000000000000000000000000000000000022",
            "block": 123,
            "entries": [
                {"index": 0, "error": None},
                {"index": 1, "error": "cast failed: target reverted"},
                {"index": 2, "error": None},
            ],
            "safeRanges": [(0, 0), (2, 2)],
        }
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, error = self.run_cli(
                [
                    "probe-registry",
                    "--spell",
                    probe.return_value["spell"],
                ]
            )
        self.assertEqual(code, 1)
        self.assertEqual(
            output,
            "Registry probe at block 123\n"
            "0x0000000000000000000000000000000000000011\n"
            "Registry: 0x0000000000000000000000000000000000000022\n"
            "├── [0] PASS\n"
            "├── [1] FAIL: cast failed: target reverted\n"
            "└── [2] PASS\n"
            "Safe ranges: [0, 0], [2, 2]\n",
        )
        self.assertIn("failing registry entry: 1", error)

    @patch("cli.emergency_spells.cli.probe_registry")
    def test_renders_clean_and_empty_registry_probes(self, probe):
        base = {
            "spell": "0x0000000000000000000000000000000000000011",
            "registry": "0x0000000000000000000000000000000000000022",
            "block": 123,
            "entries": [{"index": 0, "error": None}],
            "safeRanges": [(0, 0)],
        }
        probe.return_value = base
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, error = self.run_cli(
                ["probe-registry", "--spell", base["spell"]]
            )
        self.assertEqual(code, 0)
        self.assertEqual(error, "")
        self.assertIn("└── [0] PASS", output)

        probe.return_value = dict(base, entries=[], safeRanges=[])
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, error = self.run_cli(
                ["probe-registry", "--spell", base["spell"]]
            )
        self.assertEqual(code, 0)
        self.assertEqual(error, "")
        self.assertIn("└── [empty registry]", output)

        with patch.dict(os.environ, {}, clear=True):
            code, _, error = self.run_cli(
                [
                    "inspect-batch",
                    "--batch",
                    "0x00000000000000000000000000000000000000b1",
                ]
            )
        self.assertEqual(code, 2)
        self.assertIn("ETH_RPC_URL", error)

    @patch("cli.emergency_spells.cli.inspect_batch")
    def test_renders_batch_inspection_tree(self, inspect):
        inspect.return_value = {
            "address": "0x00000000000000000000000000000000000000b1",
            "description": "Emergency Spell | Batch:\nIncident batch",
            "leaves": [
                {
                    "address": "0x0000000000000000000000000000000000000011",
                    "description": "Emergency Spell | Line Wipe: ETH-A",
                },
                {
                    "address": "0x0000000000000000000000000000000000000022",
                    "description": "Emergency Spell | OSM Stop: ETH-A",
                },
            ],
            "leaves_unavailable": False,
            "errors": [],
        }
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, error = self.run_cli(
                [
                    "inspect-batch",
                    "--batch",
                    "0x00000000000000000000000000000000000000b1",
                ]
            )
        self.assertEqual(code, 0)
        self.assertEqual(error, "")
        self.assertEqual(
            output,
            "Emergency Spell | Batch:\\nIncident batch (0x00000000000000000000000000000000000000b1)\n"
            "├── [0] Emergency Spell | Line Wipe: ETH-A (0x0000000000000000000000000000000000000011)\n"
            "└── [1] Emergency Spell | OSM Stop: ETH-A (0x0000000000000000000000000000000000000022)\n",
        )

    @patch("cli.emergency_spells.cli.inspect_batch")
    def test_renders_partial_tree_and_exits_one(self, inspect):
        inspect.return_value = {
            "address": "0x00000000000000000000000000000000000000b1",
            "description": None,
            "leaves": [
                {
                    "address": "0x0000000000000000000000000000000000000011",
                    "description": None,
                }
            ],
            "leaves_unavailable": False,
            "errors": ["batch description failed", "leaf description failed"],
        }
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, error = self.run_cli(
                [
                    "inspect-batch",
                    "--batch",
                    "0x00000000000000000000000000000000000000b1",
                ]
            )
        self.assertEqual(code, 1)
        self.assertEqual(
            output,
            "[description unavailable] (0x00000000000000000000000000000000000000b1)\n"
            "└── [0] [description unavailable] (0x0000000000000000000000000000000000000011)\n",
        )
        self.assertIn("batch description failed; leaf description failed", error)

    @patch("cli.emergency_spells.cli.inspect_batch")
    def test_renders_unavailable_or_empty_leaf_lists(self, inspect):
        base = {
            "address": "0x00000000000000000000000000000000000000b1",
            "description": "Emergency Spell | Batch: Incident batch",
            "leaves": [],
            "leaves_unavailable": True,
            "errors": ["leaves failed"],
        }
        inspect.return_value = base
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, _ = self.run_cli(
                ["inspect-batch", "--batch", base["address"]]
            )
        self.assertEqual(code, 1)
        self.assertIn("└── [leaves unavailable]", output)

        inspect.return_value = dict(base, leaves_unavailable=False, errors=[])
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, _ = self.run_cli(
                ["inspect-batch", "--batch", base["address"]]
            )
        self.assertEqual(code, 0)
        self.assertIn("└── [no leaves]", output)

    @patch("cli.emergency_spells.cli.preflight_batch")
    def test_accepts_one_foundry_style_leaves_argument(self, preflight):
        preflight.return_value = {"configHash": "0x" + "11" * 32}
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://"}):
            code, output, _ = self.run_cli(
                [
                    "preflight-batch",
                    "--manifest",
                    str(ROOT / "deployments/1/v2.json"),
                    "--factory",
                    "0x00000000000000000000000000000000000000f1",
                    "--label",
                    "Incident batch",
                    "--leaves",
                    "[0x0000000000000000000000000000000000000011,0x0000000000000000000000000000000000000022]",
                ]
            )
        self.assertEqual(code, 0)
        self.assertIn("Config hash", output)
        self.assertEqual(
            preflight.call_args.args[3],
            [
                "0x0000000000000000000000000000000000000011",
                "0x0000000000000000000000000000000000000022",
            ],
        )

    def test_validation_errors_exit_one(self):
        code, _, error = self.run_cli(
            [
                "validate-manifest",
                "--manifest",
                str(ROOT / "cli/fixtures/v2-manifest-invalid-global.json"),
            ]
        )
        self.assertEqual(code, 1)
        self.assertIn("records[0]", error)


if __name__ == "__main__":
    unittest.main()
