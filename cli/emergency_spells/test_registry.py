import unittest

from .common import ValidationError
from .registry import diagnose_registry


SPELL = "0x0000000000000000000000000000000000000011"
REGISTRY = "0x0000000000000000000000000000000000000022"


class RegistryRunner:
    def __init__(self, count=5, failures=()):
        self.count = count
        self.failures = set(failures)
        self.calls = []

    def run(self, tool, *arguments):
        self.calls.append((tool, arguments))
        if arguments[0] == "block-number":
            return "123"
        if arguments[0] != "call":
            raise AssertionError((tool, arguments))
        address, signature = arguments[1], arguments[2]
        if address == SPELL and signature == "ilkRegistry()(address)":
            return REGISTRY
        if address == REGISTRY and signature == "count()(uint256)":
            return str(self.count)
        index = int(arguments[3])
        if index in self.failures:
            raise ValidationError(f"cast failed: entry {index} reverted")
        return "0x"


class RegistryDiagnosticTests(unittest.TestCase):
    def test_scans_every_entry_at_one_block_and_groups_safe_ranges(self):
        runner = RegistryRunner(failures=(1, 2, 4))

        result = diagnose_registry(SPELL, "mock://", runner)

        self.assertEqual(result["block"], 123)
        self.assertEqual(result["registry"], REGISTRY)
        self.assertEqual(
            result["entries"],
            [
                {"index": 0, "error": None},
                {"index": 1, "error": "cast failed: entry 1 reverted"},
                {"index": 2, "error": "cast failed: entry 2 reverted"},
                {"index": 3, "error": None},
                {"index": 4, "error": "cast failed: entry 4 reverted"},
            ],
        )
        self.assertEqual(result["safeRanges"], [(0, 0), (3, 3)])
        range_calls = [
            arguments
            for tool, arguments in runner.calls
            if tool == "cast"
            and arguments[0] == "call"
            and arguments[2] == "scheduleRange(uint256,uint256)"
        ]
        self.assertEqual([call[3:5] for call in range_calls], [(str(i), str(i)) for i in range(5)])
        self.assertTrue(all(call[-2:] == ("--block", "123") for call in range_calls))

    def test_handles_clean_all_failed_and_empty_registries(self):
        self.assertEqual(
            diagnose_registry(SPELL, "mock://", RegistryRunner(count=3))["safeRanges"],
            [(0, 2)],
        )
        self.assertEqual(
            diagnose_registry(
                SPELL, "mock://", RegistryRunner(count=3, failures=(0, 1, 2))
            )["safeRanges"],
            [],
        )
        empty = diagnose_registry(SPELL, "mock://", RegistryRunner(count=0))
        self.assertEqual(empty["entries"], [])
        self.assertEqual(empty["safeRanges"], [])

    def test_rejects_invalid_spell_and_malformed_readbacks(self):
        with self.assertRaisesRegex(ValidationError, "spell"):
            diagnose_registry("not-an-address", "mock://", RegistryRunner())

        runner = RegistryRunner()
        runner.count = "invalid"
        with self.assertRaisesRegex(ValidationError, "count"):
            diagnose_registry(SPELL, "mock://", runner)


if __name__ == "__main__":
    unittest.main()
