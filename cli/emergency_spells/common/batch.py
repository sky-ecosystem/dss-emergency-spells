from .runtime import json_output, parse_leaves, same_hex
from .validation import BYTES32_RE, require


def leaves_argument(leaves):
    return f"[{','.join(leaves)}]"


def batch_configuration(leaves, label, runner):
    encoded = runner.run(
        "cast", "abi-encode", "f(address[],string)", leaves_argument(leaves), label
    )
    return encoded, runner.run("cast", "keccak", encoded)


def read_batch_getters(address, rpc_url, runner):
    label = runner.run("cast", "call", address, "label()(string)", "--rpc-url", rpc_url)
    if label.startswith('"'):
        label = json_output(label, "batch label readback")
    leaves = runner.run(
        "cast", "call", address, "leaves()(address[])", "--rpc-url", rpc_url
    )
    config_hash = runner.run(
        "cast", "call", address, "configHash()(bytes32)", "--rpc-url", rpc_url
    )
    return {
        "label": label,
        "leaves": parse_leaves(leaves),
        "configHash": config_hash,
    }


def batch_deployed_address(
    receipt,
    factory,
    config_hash,
    runner,
    expected_batch=None,
):
    signature = runner.run("cast", "keccak", "BatchDeployed(address,bytes32)")
    expected_topic = (
        None
        if expected_batch is None
        else "0x" + expected_batch.removeprefix("0x").lower().rjust(64, "0")
    )
    matches = []
    for log in receipt.get("logs", []):
        topics = log.get("topics", [])
        if (
            same_hex(log.get("address"), factory)
            and len(topics) >= 3
            and same_hex(topics[0], signature)
            and same_hex(topics[2], config_hash)
            and same_hex(log.get("data"), "0x")
            and (expected_topic is None or same_hex(topics[1], expected_topic))
        ):
            matches.append(log)
    require(
        len(matches) == 1,
        "deployment.event",
        "expected exactly one matching BatchDeployed event",
    )
    batch_topic = matches[0]["topics"][1]
    require(
        isinstance(batch_topic, str) and BYTES32_RE.fullmatch(batch_topic) is not None,
        "deployment.event",
        "BatchDeployed batch topic is invalid",
    )
    return "0x" + batch_topic[-40:]
