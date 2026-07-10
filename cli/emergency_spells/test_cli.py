import io
import os
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

from .cli import main


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
                    "--mode",
                    "create",
                    "--label",
                    "Incident batch",
                    "--leaves",
                    "[0x0000000000000000000000000000000000000011,0x0000000000000000000000000000000000000022]",
                ]
            )
        self.assertEqual(code, 0)
        self.assertIn("Config hash", output)
        self.assertEqual(
            preflight.call_args.args[4],
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
