from .common import ADDRESS_RE, ValidationError, parse_leaves
from .common.batch import (
    batch_configuration,
    batch_deployed_address,
    leaves_argument,
    read_batch_getters,
)
from .common.deployment import verify_deployment
from .common.manifest import validate_manifest
from .common.runtime import json_output, same_hex
from .common.validation import require as _require


FACTORY_NAME = "EmergencySpellBatchFactoryV2"


def _read_description(address, rpc_url, runner):
    value = json_output(
        runner.run(
            "cast", "call", address, "description()(string)", "--rpc-url", rpc_url
        ),
        f"description readback for {address}",
    )
    if not isinstance(value, str):
        raise ValidationError(f"description readback for {address}: must be a string")
    return value


def inspect_batch(batch_address, rpc_url, runner):
    if ADDRESS_RE.fullmatch(batch_address) is None:
        raise ValidationError("batch: must be an address")

    result = {
        "address": batch_address,
        "description": None,
        "leaves": [],
        "leaves_unavailable": False,
        "errors": [],
    }
    try:
        result["description"] = _read_description(batch_address, rpc_url, runner)
    except ValidationError as error:
        result["errors"].append(f"{batch_address} description(): {error}")

    try:
        leaves_readback = runner.run(
            "cast",
            "call",
            batch_address,
            "leaves()(address[])",
            "--rpc-url",
            rpc_url,
        )
        leaves = (
            [] if leaves_readback.strip() == "[]" else parse_leaves(leaves_readback)
        )
    except ValidationError as error:
        result["leaves_unavailable"] = True
        result["errors"].append(f"{batch_address} leaves(): {error}")
        return result

    for leaf_address in leaves:
        leaf = {"address": leaf_address, "description": None}
        try:
            leaf["description"] = _read_description(leaf_address, rpc_url, runner)
        except ValidationError as error:
            result["errors"].append(f"{leaf_address} description(): {error}")
        result["leaves"].append(leaf)
    return result


def preflight_batch(
    manifest,
    factory_address,
    label,
    leaves,
    rpc_url,
    runner,
    root,
):
    _require(bool(label), "label", "must not be empty")
    _require(bool(leaves), "leaves", "must not be empty")
    by_address = validate_manifest(manifest)
    factory = by_address.get(factory_address.lower())
    ready = (
        factory is not None
        and factory["contractName"] == FACTORY_NAME
        and factory["kind"] == "infrastructure"
        and factory["reviews"]["directUse"]["status"] == "approved"
        and factory["operationalStatus"] == "incident-ready"
    )
    _require(ready, "factory", "is not incident-ready batch infrastructure")
    verify_deployment(manifest, factory_address, rpc_url, runner, root)

    normalized = [leaf.lower() for leaf in leaves]
    _require(
        len(normalized) == len(set(normalized)),
        "leaves",
        "contains a duplicate leaf",
    )
    for leaf_address in leaves:
        leaf = by_address.get(leaf_address.lower())
        eligible = (
            leaf is not None
            and leaf["kind"] == "leaf"
            and leaf["batchEligible"]
            and leaf["reviews"]["directUse"]["status"] == "approved"
            and leaf["reviews"]["batchUse"]["status"] == "approved"
            and leaf["operationalStatus"] == "incident-ready"
        )
        _require(
            eligible,
            "leaves",
            f"{leaf_address} is not incident-ready for batch use",
        )
        codehash = runner.run("cast", "codehash", leaf_address, "--rpc-url", rpc_url)
        _require(
            same_hex(codehash, leaf["runtimeCodehash"]),
            "leaves",
            f"runtime codehash mismatch for {leaf_address}",
        )

    _encoded, config_hash = batch_configuration(leaves, label, runner)
    return {"configHash": config_hash}


def _verify_batch_readbacks(
    record, address, leaves, label, config_hash, rpc_url, runner
):
    readbacks = read_batch_getters(address, rpc_url, runner)
    _require(readbacks["label"] == label, "batch.label", "getter readback mismatch")
    _require(
        [leaf.lower() for leaf in readbacks["leaves"]]
        == [leaf.lower() for leaf in leaves],
        "batch.leaves",
        "getter readback mismatch",
    )
    _require(
        same_hex(readbacks["configHash"], config_hash),
        "batch.configHash",
        "getter readback mismatch",
    )
    for signature, expected in record["immutableReadbacks"].items():
        actual = runner.run("cast", "call", address, signature, "--rpc-url", rpc_url)
        _require(
            same_hex(actual, expected)
            if expected.startswith("0x")
            else actual == expected,
            f"immutableReadbacks.{signature}",
            "does not match deployed value",
        )


def verify_batch(
    manifest,
    batch_address,
    factory_address,
    transaction_hash,
    label,
    leaves,
    rpc_url,
    runner,
    root,
):
    by_address = validate_manifest(manifest)
    factory = by_address.get(factory_address.lower())
    _require(
        factory is not None
        and factory["contractName"] == FACTORY_NAME
        and factory["kind"] == "infrastructure",
        "factory",
        "record not found",
    )
    verify_deployment(manifest, factory_address, rpc_url, runner, root)

    for leaf_address in leaves:
        leaf = by_address.get(leaf_address.lower())
        _require(
            leaf is not None and leaf["kind"] == "leaf",
            "leaves",
            f"leaf record not found: {leaf_address}",
        )
        actual = runner.run("cast", "codehash", leaf_address, "--rpc-url", rpc_url)
        _require(
            same_hex(actual, leaf["runtimeCodehash"]),
            "leaves",
            f"runtime codehash mismatch for {leaf_address}",
        )

    record = by_address.get(batch_address.lower())
    _require(
        record is not None and record["kind"] == "batch", "batch", "record not found"
    )
    batch = record["batch"]
    configuration_matches = (
        same_hex(record["deployment"]["transactionHash"], transaction_hash)
        and same_hex(batch["factory"], factory_address)
        and batch["label"] == label
        and [leaf.lower() for leaf in batch["leaves"]]
        == [leaf.lower() for leaf in leaves]
        and batch["factoryEventVerified"]
    )
    _require(configuration_matches, "batch", "manifest configuration mismatch")

    encoded, config_hash = batch_configuration(leaves, label, runner)
    _require(
        same_hex(record["deployment"]["constructorArguments"], encoded),
        "deployment.constructorArguments",
        "does not match batch configuration",
    )
    _require(
        same_hex(batch["configHash"], config_hash),
        "batch.configHash",
        "does not match batch configuration",
    )
    _verify_batch_readbacks(
        record,
        batch_address,
        leaves,
        label,
        config_hash,
        rpc_url,
        runner,
    )
    actual_codehash = runner.run(
        "cast", "codehash", batch_address, "--rpc-url", rpc_url
    )
    _require(
        same_hex(actual_codehash, record["runtimeCodehash"]),
        "runtimeCodehash",
        "does not match deployed batch",
    )

    expected_input = runner.run(
        "cast", "calldata", "deploy(address[],string)", leaves_argument(leaves), label
    )
    transaction = json_output(
        runner.run("cast", "tx", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "batch deployment transaction",
    )
    _require(
        same_hex(transaction.get("to"), factory_address),
        "deployment.transactionHash",
        "factory call target mismatch",
    )
    _require(
        same_hex(transaction.get("input"), expected_input),
        "deployment.transactionHash",
        "factory calldata mismatch",
    )

    receipt = json_output(
        runner.run("cast", "receipt", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "batch deployment receipt",
    )
    _require(
        receipt.get("status") == "0x1",
        "deployment.transactionHash",
        "transaction failed",
    )
    _require(
        same_hex(receipt.get("transactionHash"), transaction_hash),
        "deployment.transactionHash",
        "receipt transaction hash mismatch",
    )
    try:
        block_number = int(receipt.get("blockNumber"), 0)
    except (TypeError, ValueError) as error:
        raise ValidationError(
            "deployment.blockNumber: receipt block is invalid"
        ) from error
    _require(
        block_number == record["deployment"]["blockNumber"],
        "deployment.blockNumber",
        "does not match receipt",
    )
    batch_deployed_address(
        receipt,
        factory_address,
        config_hash,
        runner,
        batch_address,
    )
    return record
