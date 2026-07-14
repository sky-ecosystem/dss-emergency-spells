from .common import ADDRESS_RE, BYTES32_RE, ValidationError
from .common.batch import (
    batch_configuration,
    batch_deployed_address,
    leaves_argument,
    read_batch_getters,
)
from .common.deployment import (
    verify_deployment,
    verify_source,
)
from .common.manifest import CONTRACT_NAME_RE, validate_manifest
from .common.runtime import json_output, same_hex
from .common.validation import require as _require


SPELL_KINDS = {"leaf", "registry-global"}
DIRECT_KINDS = SPELL_KINDS | {"infrastructure"}
SPELL_READBACKS = {"action()(address)", "pause()(address)"}
BATCH_ARTIFACT = "src/EmergencySpellBatchV2.sol:EmergencySpellBatchV2"
FACTORY_NAME = "EmergencySpellBatchFactoryV2"


def _contract_name(artifact):
    try:
        source, contract_name = artifact.rsplit(":", 1)
    except ValueError as error:
        raise ValidationError(
            "artifact: must identify a contract under src/"
        ) from error
    valid = (
        CONTRACT_NAME_RE.fullmatch(contract_name) is not None
        and source.startswith("src/")
        and (
            source == f"src/{contract_name}.sol"
            or source.endswith(f"/{contract_name}.sol")
        )
    )
    _require(valid, "artifact", "must identify contractName in its src/ source file")
    return contract_name


def _positive_block(value):
    try:
        block_number = int(value, 0)
    except (TypeError, ValueError) as error:
        raise ValidationError(
            "deployment.blockNumber: receipt block is invalid"
        ) from error
    _require(block_number >= 1, "deployment.blockNumber", "must be positive")
    return block_number


def _readback(address, signature, rpc_url, runner):
    value = runner.run("cast", "call", address, signature, "--rpc-url", rpc_url)
    if value.startswith('"'):
        value = json_output(value, f"immutableReadbacks.{signature}")
    _require(
        isinstance(value, str) and value != "",
        f"immutableReadbacks.{signature}",
        "must be a nonempty string",
    )
    return value


def _reviews(kind):
    batch_use = (
        {"status": "pending", "evidence": ""}
        if kind == "leaf"
        else {
            "status": "not-applicable",
            "evidence": f"{kind} records are direct-use only.",
        }
    )
    return {
        "directUse": {"status": "pending", "evidence": ""},
        "batchUse": batch_use,
    }


def draft_deployment(
    artifact,
    kind,
    transaction_hash,
    subjects,
    parameters,
    immutable_readbacks,
    rpc_url,
    runner,
    root,
):
    contract_name = _contract_name(artifact)
    _require(
        kind in DIRECT_KINDS, "kind", "must be leaf, registry-global, or infrastructure"
    )
    _require(
        BYTES32_RE.fullmatch(transaction_hash) is not None,
        "transactionHash",
        "must be bytes32",
    )
    if kind in SPELL_KINDS:
        _require(
            bool(subjects),
            "subjects",
            "spell must declare at least one emergency subject",
        )

    source_commit = runner.run("git", "rev-parse", "HEAD")
    verify_source({"sourceCommit": source_commit}, runner)
    creation_code = runner.run(
        "forge", "inspect", "--root", str(root), "--force", artifact, "bytecode"
    )
    transaction = json_output(
        runner.run("cast", "tx", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "deployment transaction",
    )
    _require(
        transaction.get("to") is None,
        "transactionHash",
        "transaction is not direct CREATE",
    )
    input_bytes = transaction.get("input", "").removeprefix("0x")
    creation_bytes = creation_code.removeprefix("0x")
    _require(
        input_bytes.lower().startswith(creation_bytes.lower()),
        "constructorArguments",
        "transaction input does not start with compiled creation bytecode",
    )
    constructor_arguments = "0x" + input_bytes[len(creation_bytes) :]

    receipt = json_output(
        runner.run("cast", "receipt", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "deployment receipt",
    )
    _require(receipt.get("status") == "0x1", "transactionHash", "transaction failed")
    _require(
        same_hex(receipt.get("transactionHash"), transaction_hash),
        "transactionHash",
        "receipt transaction hash mismatch",
    )
    address = receipt.get("contractAddress")
    _require(
        isinstance(address, str) and ADDRESS_RE.fullmatch(address) is not None,
        "address",
        "receipt contract address is invalid",
    )
    block_number = _positive_block(receipt.get("blockNumber"))
    runtime_codehash = runner.run("cast", "codehash", address, "--rpc-url", rpc_url)
    _require(
        BYTES32_RE.fullmatch(runtime_codehash) is not None,
        "runtimeCodehash",
        "must be bytes32",
    )

    signatures = set(subjects) | set(parameters) | set(immutable_readbacks)
    if kind in SPELL_KINDS:
        signatures |= SPELL_READBACKS
    for signature in signatures:
        _require(
            isinstance(signature, str) and signature != "",
            "immutableReadbacks",
            "signatures must be nonempty strings",
        )
    readbacks = {
        signature: _readback(address, signature, rpc_url, runner)
        for signature in sorted(signatures)
    }

    return {
        "contractName": contract_name,
        "artifact": artifact,
        "kind": kind,
        "address": address,
        "runtimeCodehash": runtime_codehash,
        "sourceCommit": source_commit,
        "deployment": {
            "transactionHash": transaction_hash,
            "blockNumber": block_number,
            "constructorArguments": constructor_arguments,
        },
        "immutableReadbacks": readbacks,
        "subjects": {signature: readbacks[signature] for signature in sorted(subjects)},
        "parameters": {
            signature: readbacks[signature] for signature in sorted(parameters)
        },
        "reviews": _reviews(kind),
        "batchEligible": False,
        "operationalStatus": "deployed",
    }


def draft_batch(
    manifest,
    factory_address,
    transaction_hash,
    label,
    leaves,
    rpc_url,
    runner,
    root,
):
    _require(bool(label), "label", "must not be empty")
    _require(bool(leaves), "leaves", "must not be empty")
    _require(
        BYTES32_RE.fullmatch(transaction_hash) is not None,
        "transactionHash",
        "must be bytes32",
    )

    normalized_leaves = [leaf.lower() for leaf in leaves]
    _require(
        all(ADDRESS_RE.fullmatch(leaf) is not None for leaf in leaves),
        "leaves",
        "must contain addresses",
    )
    _require(
        len(normalized_leaves) == len(set(normalized_leaves)),
        "leaves",
        "contains a duplicate leaf",
    )

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
        actual_codehash = runner.run(
            "cast", "codehash", leaf_address, "--rpc-url", rpc_url
        )
        _require(
            same_hex(actual_codehash, leaf["runtimeCodehash"]),
            "leaves",
            f"runtime codehash mismatch for {leaf_address}",
        )

    constructor_arguments, config_hash = batch_configuration(
        leaves, label, runner
    )
    _require(
        BYTES32_RE.fullmatch(config_hash) is not None, "configHash", "must be bytes32"
    )

    expected_calldata = runner.run(
        "cast", "calldata", "deploy(address[],string)", leaves_argument(leaves), label
    )
    transaction = json_output(
        runner.run("cast", "tx", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "batch deployment transaction",
    )
    _require(
        same_hex(transaction.get("to"), factory_address),
        "transactionHash",
        "factory call target mismatch",
    )
    _require(
        same_hex(transaction.get("input"), expected_calldata),
        "transactionHash",
        "factory calldata mismatch",
    )

    receipt = json_output(
        runner.run("cast", "receipt", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "batch deployment receipt",
    )
    _require(receipt.get("status") == "0x1", "transactionHash", "transaction failed")
    _require(
        same_hex(receipt.get("transactionHash"), transaction_hash),
        "transactionHash",
        "receipt transaction hash mismatch",
    )
    block_number = _positive_block(receipt.get("blockNumber"))

    batch_address = batch_deployed_address(receipt, factory_address, config_hash, runner)
    getter_readbacks = read_batch_getters(batch_address, rpc_url, runner)
    _require(
        getter_readbacks["label"] == label,
        "batch.label",
        "getter readback mismatch",
    )
    _require(
        [leaf.lower() for leaf in getter_readbacks["leaves"]] == normalized_leaves,
        "batch.leaves",
        "getter readback mismatch",
    )
    _require(
        same_hex(getter_readbacks["configHash"], config_hash),
        "batch.configHash",
        "getter readback mismatch",
    )

    runtime_codehash = runner.run(
        "cast", "codehash", batch_address, "--rpc-url", rpc_url
    )
    _require(
        BYTES32_RE.fullmatch(runtime_codehash) is not None,
        "runtimeCodehash",
        "must be bytes32",
    )
    immutable_readbacks = {
        signature: _readback(batch_address, signature, rpc_url, runner)
        for signature in sorted(SPELL_READBACKS | {"configHash()(bytes32)"})
    }

    return {
        "contractName": "EmergencySpellBatchV2",
        "artifact": BATCH_ARTIFACT,
        "kind": "batch",
        "address": batch_address,
        "runtimeCodehash": runtime_codehash,
        "sourceCommit": factory["sourceCommit"],
        "deployment": {
            "transactionHash": transaction_hash,
            "blockNumber": block_number,
            "constructorArguments": constructor_arguments,
        },
        "immutableReadbacks": immutable_readbacks,
        "subjects": {},
        "parameters": {},
        "reviews": _reviews("batch"),
        "batchEligible": False,
        "operationalStatus": "deployed",
        "batch": {
            "label": label,
            "leaves": leaves,
            "configHash": config_hash,
            "factory": factory_address,
            "getterReadbacks": {
                "label": getter_readbacks["label"],
                "leaves": getter_readbacks["leaves"],
                "configHash": getter_readbacks["configHash"],
            },
            "factoryEventVerified": True,
            "atomicSimulation": {
                "status": "pending",
                "reference": "",
                "chainId": manifest["chainId"],
                "blockNumber": 0,
                "batch": batch_address,
                "configHash": config_hash,
                "chief": "",
                "chiefAuthorizationVerified": False,
                "downstreamCallerVerified": False,
                "atomicRollbackVerified": False,
            },
        },
    }
