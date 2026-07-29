import unittest

from .batch import batch_configuration, batch_deployed_address, read_batch_getters
from .validation import ValidationError


FACTORY = "0x00000000000000000000000000000000000000f1"
BATCH = "0x00000000000000000000000000000000000000b1"
LEAF = "0x0000000000000000000000000000000000000011"
CONFIG_HASH = "0x" + "66" * 32
EVENT_SIGNATURE = "0x" + "77" * 32


class Runner:
    def run(self, tool, *arguments):
        command = arguments[0]
        if command == "abi-encode":
            return "0xabcdef"
        if command == "keccak":
            return (
                EVENT_SIGNATURE
                if arguments[1] == "BatchDeployed(address,bytes32)"
                else CONFIG_HASH
            )
        if command == "call":
            return {
                "label()(string)": '"Incident batch"',
                "leaves()(address[])": f"[{LEAF}]",
                "configHash()(bytes32)": CONFIG_HASH,
            }[arguments[2]]
        raise AssertionError((tool, arguments))


class BatchCommonTests(unittest.TestCase):
    def test_encodes_configuration_and_reads_getters(self):
        runner = Runner()

        encoded, config_hash = batch_configuration([LEAF], "Incident batch", runner)
        getters = read_batch_getters(BATCH, "mock://", runner)

        self.assertEqual(encoded, "0xabcdef")
        self.assertEqual(config_hash, CONFIG_HASH)
        self.assertEqual(
            getters,
            {
                "label": "Incident batch",
                "leaves": [LEAF],
                "configHash": CONFIG_HASH,
            },
        )

    def test_resolves_and_optionally_checks_batch_event_address(self):
        runner = Runner()
        receipt = {
            "logs": [
                {
                    "address": FACTORY,
                    "topics": [
                        EVENT_SIGNATURE,
                        "0x" + "0" * 24 + BATCH[2:],
                        CONFIG_HASH,
                    ],
                    "data": "0x",
                }
            ]
        }

        self.assertEqual(
            batch_deployed_address(receipt, FACTORY, CONFIG_HASH, runner),
            BATCH,
        )
        self.assertEqual(
            batch_deployed_address(
                receipt, FACTORY, CONFIG_HASH, runner, BATCH
            ),
            BATCH,
        )
        with self.assertRaisesRegex(ValidationError, "BatchDeployed"):
            batch_deployed_address(
                receipt,
                FACTORY,
                CONFIG_HASH,
                runner,
                "0x00000000000000000000000000000000000000b2",
            )


if __name__ == "__main__":
    unittest.main()
