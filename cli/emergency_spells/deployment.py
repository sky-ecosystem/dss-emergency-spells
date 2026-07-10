import json

from .common import ValidationError
from .manifest import _require, validate_manifest


def _json_output(value, context):
    try:
        return json.loads(value)
    except json.JSONDecodeError as error:
        raise ValidationError(f"{context}: command returned invalid JSON") from error


def _same_hex(left, right):
    return (
        isinstance(left, str)
        and isinstance(right, str)
        and left.lower() == right.lower()
    )


def verify_source(record, runner):
    commit = record["sourceCommit"]
    _require(
        runner.run("git", "status", "--porcelain", "--untracked-files=all") == "",
        "sourceCommit",
        "repository has tracked, untracked, or submodule changes",
    )
    runner.run("git", "verify-commit", commit)
    runner.run(
        "git",
        "diff",
        "--quiet",
        commit,
        "--",
        "src",
        "foundry.toml",
        ".gitmodules",
        "lib",
        "remappings.txt",
    )


def verify_deployment(manifest, address, rpc_url, runner, root, *, allow_batch=False):
    by_address = validate_manifest(manifest)
    _require(
        runner.run("cast", "chain-id", "--rpc-url", rpc_url)
        == str(manifest["chainId"]),
        "chainId",
        "RPC does not match manifest",
    )
    record = by_address.get(address.lower())
    _require(
        record is not None, "address", "must resolve to exactly one manifest record"
    )
    if record["kind"] == "batch" and not allow_batch:
        raise ValidationError(
            "address: batch records must be verified with verify-batch"
        )

    verify_source(record, runner)
    creation_code = runner.run(
        "forge",
        "inspect",
        "--root",
        str(root),
        "--force",
        record["artifact"],
        "bytecode",
    )
    expected_input = (
        "0x"
        + creation_code.removeprefix("0x")
        + record["deployment"]["constructorArguments"].removeprefix("0x")
    )
    transaction_hash = record["deployment"]["transactionHash"]
    transaction = _json_output(
        runner.run("cast", "tx", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "deployment transaction",
    )
    _require(
        transaction.get("to") is None,
        "deployment.transactionHash",
        "transaction is not direct CREATE",
    )
    _require(
        _same_hex(transaction.get("input"), expected_input),
        "deployment.constructorArguments",
        "deployment initcode or constructor arguments mismatch",
    )

    actual_codehash = runner.run("cast", "codehash", address, "--rpc-url", rpc_url)
    _require(
        _same_hex(actual_codehash, record["runtimeCodehash"]),
        "runtimeCodehash",
        "does not match deployed code",
    )
    for signature, expected in record["immutableReadbacks"].items():
        actual = runner.run("cast", "call", address, signature, "--rpc-url", rpc_url)
        if actual.startswith('"'):
            actual = _json_output(actual, f"immutableReadbacks.{signature}")
        matches = (
            _same_hex(actual, expected)
            if isinstance(actual, str)
            and isinstance(expected, str)
            and actual.startswith("0x")
            and expected.startswith("0x")
            else actual == expected
        )
        _require(
            matches, f"immutableReadbacks.{signature}", "does not match deployed value"
        )

    receipt = _json_output(
        runner.run("cast", "receipt", transaction_hash, "--rpc-url", rpc_url, "--json"),
        "deployment receipt",
    )
    _require(
        receipt.get("status") == "0x1",
        "deployment.transactionHash",
        "transaction failed",
    )
    _require(
        _same_hex(receipt.get("contractAddress"), address),
        "deployment.address",
        "receipt contract address mismatch",
    )
    _require(
        _same_hex(receipt.get("transactionHash"), transaction_hash),
        "deployment.transactionHash",
        "receipt transaction hash mismatch",
    )
    try:
        receipt_block = int(receipt.get("blockNumber"), 0)
    except (TypeError, ValueError) as error:
        raise ValidationError(
            "deployment.blockNumber: receipt block is invalid"
        ) from error
    _require(
        receipt_block == record["deployment"]["blockNumber"],
        "deployment.blockNumber",
        "does not match receipt",
    )
    return record
