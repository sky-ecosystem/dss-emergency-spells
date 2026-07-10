from .common import ADDRESS_RE, ValidationError, parse_leaves
from .deployment import _json_output, _same_hex, verify_deployment
from .manifest import _require, validate_manifest


FACTORY_NAME = "EmergencySpellBatchFactoryV2"


def _read_description(address, rpc_url, runner):
    value = _json_output(
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


def _leaves_argument(leaves):
    return f"[{','.join(leaves)}]"


def _config_hash(leaves, label, runner):
    encoded = runner.run(
        "cast", "abi-encode", "f(address[],string)", _leaves_argument(leaves), label
    )
    return encoded, runner.run("cast", "keccak", encoded)


def preflight_batch(
    manifest,
    factory_address,
    deployment_mode,
    label,
    ordered_leaves,
    rpc_url,
    runner,
    root,
):
    _require(
        deployment_mode in {"create", "create2"},
        "deploymentMode",
        "must be create or create2",
    )
    _require(bool(label), "label", "must not be empty")
    _require(bool(ordered_leaves), "orderedLeaves", "must not be empty")
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

    normalized = [leaf.lower() for leaf in ordered_leaves]
    _require(
        len(normalized) == len(set(normalized)),
        "orderedLeaves",
        "contains a duplicate leaf",
    )
    if deployment_mode == "create2":
        _require(
            normalized == sorted(normalized),
            "orderedLeaves",
            "must be strictly ordered for create2",
        )
    for leaf_address in ordered_leaves:
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
            "orderedLeaves",
            f"{leaf_address} is not incident-ready for batch use",
        )
        codehash = runner.run("cast", "codehash", leaf_address, "--rpc-url", rpc_url)
        _require(
            _same_hex(codehash, leaf["runtimeCodehash"]),
            "orderedLeaves",
            f"runtime codehash mismatch for {leaf_address}",
        )

    _encoded, config_hash = _config_hash(ordered_leaves, label, runner)
    result = {"configHash": config_hash}
    if deployment_mode == "create2":
        result["predictedBatch"] = runner.run(
            "cast",
            "call",
            factory_address,
            "previewDeterministicAddress(address[],string)(address)",
            _leaves_argument(ordered_leaves),
            label,
            "--rpc-url",
            rpc_url,
        )
    return result


def _verify_batch_readbacks(
    record, address, leaves, label, config_hash, rpc_url, runner
):
    label_readback = runner.run(
        "cast", "call", address, "label()(string)", "--rpc-url", rpc_url
    )
    if label_readback.startswith('"'):
        label_readback = _json_output(label_readback, "batch label readback")
    _require(label_readback == label, "batch.label", "getter readback mismatch")
    leaves_readback = runner.run(
        "cast", "call", address, "leaves()(address[])", "--rpc-url", rpc_url
    )
    _require(
        [leaf.lower() for leaf in parse_leaves(leaves_readback)]
        == [leaf.lower() for leaf in leaves],
        "batch.orderedLeaves",
        "getter readback mismatch",
    )
    actual_config = runner.run(
        "cast", "call", address, "configHash()(bytes32)", "--rpc-url", rpc_url
    )
    _require(
        _same_hex(actual_config, config_hash),
        "batch.configHash",
        "getter readback mismatch",
    )
    for signature, expected in record["immutableReadbacks"].items():
        actual = runner.run("cast", "call", address, signature, "--rpc-url", rpc_url)
        _require(
            _same_hex(actual, expected)
            if expected.startswith("0x")
            else actual == expected,
            f"immutableReadbacks.{signature}",
            "does not match deployed value",
        )


def _verify_event(receipt, factory, batch, config_hash, mode, runner):
    signature = runner.run(
        "cast", "keccak", "BatchDeployed(address,bytes32,uint8)"
    ).lower()
    batch_topic = "0x" + batch.removeprefix("0x").lower().rjust(64, "0")
    mode_data = "0x" + ("1" if mode == "create2" else "0").rjust(64, "0")
    matches = 0
    for log in receipt.get("logs", []):
        topics = log.get("topics", [])
        if (
            isinstance(log.get("address"), str)
            and log["address"].lower() == factory.lower()
            and len(topics) >= 3
            and topics[0].lower() == signature
            and topics[1].lower() == batch_topic
            and topics[2].lower() == config_hash.lower()
            and log.get("data", "").lower() == mode_data
        ):
            matches += 1
    _require(
        matches == 1,
        "deployment.event",
        "expected exactly one matching BatchDeployed event",
    )


def verify_batch(
    manifest,
    batch_address,
    factory_address,
    transaction_hash,
    deployment_mode,
    label,
    ordered_leaves,
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

    for leaf_address in ordered_leaves:
        leaf = by_address.get(leaf_address.lower())
        _require(
            leaf is not None and leaf["kind"] == "leaf",
            "orderedLeaves",
            f"leaf record not found: {leaf_address}",
        )
        actual = runner.run("cast", "codehash", leaf_address, "--rpc-url", rpc_url)
        _require(
            _same_hex(actual, leaf["runtimeCodehash"]),
            "orderedLeaves",
            f"runtime codehash mismatch for {leaf_address}",
        )

    record = by_address.get(batch_address.lower())
    _require(
        record is not None and record["kind"] == "batch", "batch", "record not found"
    )
    batch = record["batch"]
    configuration_matches = (
        _same_hex(record["deployment"]["transactionHash"], transaction_hash)
        and _same_hex(batch["factory"], factory_address)
        and batch["deploymentMode"] == deployment_mode
        and batch["label"] == label
        and [leaf.lower() for leaf in batch["orderedLeaves"]]
        == [leaf.lower() for leaf in ordered_leaves]
        and batch["factoryEventVerified"]
    )
    _require(configuration_matches, "batch", "manifest configuration mismatch")

    encoded, config_hash = _config_hash(ordered_leaves, label, runner)
    _require(
        _same_hex(record["deployment"]["constructorArguments"], encoded),
        "deployment.constructorArguments",
        "does not match batch configuration",
    )
    _require(
        _same_hex(batch["configHash"], config_hash),
        "batch.configHash",
        "does not match batch configuration",
    )
    _verify_batch_readbacks(
        record,
        batch_address,
        ordered_leaves,
        label,
        config_hash,
        rpc_url,
        runner,
    )
    actual_codehash = runner.run(
        "cast", "codehash", batch_address, "--rpc-url", rpc_url
    )
    _require(
        _same_hex(actual_codehash, record["runtimeCodehash"]),
        "runtimeCodehash",
        "does not match deployed batch",
    )

    function = (
        "deployDeterministic(address[],string)"
        if deployment_mode == "create2"
        else "deploy(address[],string)"
    )
    expected_input = runner.run(
        "cast", "calldata", function, _leaves_argument(ordered_leaves), label
    )
    transaction = _json_output(
        runner.run("cast", "tx", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "batch deployment transaction",
    )
    _require(
        _same_hex(transaction.get("to"), factory_address),
        "deployment.transactionHash",
        "factory call target mismatch",
    )
    _require(
        _same_hex(transaction.get("input"), expected_input),
        "deployment.transactionHash",
        "factory calldata mismatch",
    )

    receipt = _json_output(
        runner.run("cast", "receipt", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "batch deployment receipt",
    )
    _require(
        receipt.get("status") == "0x1",
        "deployment.transactionHash",
        "transaction failed",
    )
    _require(
        _same_hex(receipt.get("transactionHash"), transaction_hash),
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
    _verify_event(
        receipt,
        factory_address,
        batch_address,
        config_hash,
        deployment_mode,
        runner,
    )

    if deployment_mode == "create2":
        creation_code = runner.run(
            "forge",
            "inspect",
            "--root",
            str(root),
            "--force",
            record["artifact"],
            "bytecode",
        )
        init_code = "0x" + creation_code.removeprefix("0x") + encoded.removeprefix("0x")
        predicted = runner.run(
            "cast",
            "create2",
            "--deployer",
            factory_address,
            "--salt",
            config_hash,
            "--init-code",
            init_code,
        )
        _require(
            _same_hex(predicted, batch_address),
            "batch.address",
            "independent CREATE2 prediction mismatch",
        )
    return record
