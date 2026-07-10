import os
import unittest
from unittest.mock import patch

from cli.emergency_spells.common import (
    DependencyError,
    ValidationError,
    parse_leaves,
    require_rpc_url,
)


ADDRESS_A = "0x0000000000000000000000000000000000000011"
ADDRESS_B = "0x0000000000000000000000000000000000000022"


class ParseLeavesTest(unittest.TestCase):
    def test_parses_foundry_array_and_preserves_order(self):
        self.assertEqual(
            parse_leaves(f"[{ADDRESS_B}, {ADDRESS_A}]"), [ADDRESS_B, ADDRESS_A]
        )

    def test_rejects_malformed_or_empty_arrays(self):
        for value in ("", "[]", ADDRESS_A, f"[{ADDRESS_A},]", "[nope]"):
            with self.subTest(value=value), self.assertRaises(ValidationError):
                parse_leaves(value)


class RpcUrlTest(unittest.TestCase):
    def test_reads_eth_rpc_url(self):
        with patch.dict(os.environ, {"ETH_RPC_URL": "mock://mainnet"}, clear=True):
            self.assertEqual(require_rpc_url(), "mock://mainnet")

    def test_rejects_missing_eth_rpc_url(self):
        with patch.dict(os.environ, {}, clear=True), self.assertRaises(DependencyError):
            require_rpc_url()


if __name__ == "__main__":
    unittest.main()
