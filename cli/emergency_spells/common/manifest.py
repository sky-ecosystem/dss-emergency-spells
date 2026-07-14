import re

from .validation import (
    ADDRESS_RE,
    BYTES32_RE,
    BYTES_RE,
    COMMIT_RE,
    integer as _integer,
    matches as _matches,
    nonempty as _nonempty,
    object_ as _object,
    require as _require,
)


SPELL_BASE = ("action()(address)", "pause()(address)")
CONTRACT_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def _review(review, path):
    _object(review, path, {"status", "evidence"})
    _require(
        review["status"] in {"pending", "approved", "rejected", "not-applicable"},
        f"{path}.status",
        "invalid status",
    )
    _require(
        _nonempty(review["evidence"]), f"{path}.evidence", "must be a nonempty string"
    )


def _deployment(deployment, path):
    _object(
        deployment, path, {"transactionHash", "blockNumber", "constructorArguments"}
    )
    _require(
        _matches(deployment["transactionHash"], BYTES32_RE),
        f"{path}.transactionHash",
        "must be bytes32",
    )
    _require(
        _integer(deployment["blockNumber"]),
        f"{path}.blockNumber",
        "must be a positive integer",
    )
    _require(
        _matches(deployment["constructorArguments"], BYTES_RE),
        f"{path}.constructorArguments",
        "must be hex bytes",
    )


def _simulation(simulation, path):
    keys = {
        "status",
        "reference",
        "chainId",
        "blockNumber",
        "batch",
        "configHash",
        "chief",
        "chiefAuthorizationVerified",
        "downstreamCallerVerified",
        "atomicRollbackVerified",
    }
    _object(simulation, path, keys)
    _require(
        simulation["status"] in {"pending", "approved", "rejected"},
        f"{path}.status",
        "invalid status",
    )
    _require(
        _nonempty(simulation["reference"]),
        f"{path}.reference",
        "must be a nonempty string",
    )
    for field in ("chainId", "blockNumber"):
        _require(
            _integer(simulation[field]), f"{path}.{field}", "must be a positive integer"
        )
    for field in ("batch", "chief"):
        _require(
            _matches(simulation[field], ADDRESS_RE),
            f"{path}.{field}",
            "must be an address",
        )
    _require(
        _matches(simulation["configHash"], BYTES32_RE),
        f"{path}.configHash",
        "must be bytes32",
    )
    for field in (
        "chiefAuthorizationVerified",
        "downstreamCallerVerified",
        "atomicRollbackVerified",
    ):
        _require(
            isinstance(simulation[field], bool), f"{path}.{field}", "must be a boolean"
        )


def _address_list(value, path):
    _require(isinstance(value, list) and value, path, "must be a nonempty array")
    for index, address in enumerate(value):
        _require(
            _matches(address, ADDRESS_RE), f"{path}[{index}]", "must be an address"
        )
    lowered = [address.lower() for address in value]
    _require(len(lowered) == len(set(lowered)), path, "contains duplicate addresses")
    return lowered


def _batch(batch, path):
    keys = {
        "label",
        "leaves",
        "configHash",
        "factory",
        "getterReadbacks",
        "factoryEventVerified",
        "atomicSimulation",
    }
    _object(batch, path, keys)
    _require(_nonempty(batch["label"]), f"{path}.label", "must be a nonempty string")
    _address_list(batch["leaves"], f"{path}.leaves")
    _require(
        _matches(batch["configHash"], BYTES32_RE),
        f"{path}.configHash",
        "must be bytes32",
    )
    _require(
        _matches(batch["factory"], ADDRESS_RE), f"{path}.factory", "must be an address"
    )
    readbacks = batch["getterReadbacks"]
    _object(readbacks, f"{path}.getterReadbacks", {"label", "leaves", "configHash"})
    _require(
        _nonempty(readbacks["label"]),
        f"{path}.getterReadbacks.label",
        "must be a nonempty string",
    )
    _address_list(readbacks["leaves"], f"{path}.getterReadbacks.leaves")
    _require(
        _matches(readbacks["configHash"], BYTES32_RE),
        f"{path}.getterReadbacks.configHash",
        "must be bytes32",
    )
    _require(
        isinstance(batch["factoryEventVerified"], bool),
        f"{path}.factoryEventVerified",
        "must be a boolean",
    )
    _simulation(batch["atomicSimulation"], f"{path}.atomicSimulation")


def _record(record, chain_id, index):
    path = f"records[{index}]"
    base_keys = {
        "contractName",
        "artifact",
        "kind",
        "address",
        "runtimeCodehash",
        "sourceCommit",
        "deployment",
        "immutableReadbacks",
        "subjects",
        "parameters",
        "reviews",
        "batchEligible",
        "operationalStatus",
    }
    _require(isinstance(record, dict), path, "must be an object")
    contract_name = record.get("contractName")
    _require(
        _matches(contract_name, CONTRACT_NAME_RE),
        f"{path}.contractName",
        "must be a Solidity contract name",
    )
    kind = record.get("kind")
    _require(
        kind in {"leaf", "registry-global", "batch", "infrastructure"},
        f"{path}.kind",
        "invalid kind",
    )
    keys = base_keys | ({"batch"} if kind == "batch" else set())
    _object(record, path, keys)
    artifact = record["artifact"]
    expected_suffix = f"/{contract_name}.sol:{contract_name}"
    _require(
        isinstance(artifact, str)
        and artifact.startswith("src/")
        and (
            artifact == f"src/{contract_name}.sol:{contract_name}"
            or artifact.endswith(expected_suffix)
        ),
        f"{path}.artifact",
        "must identify contractName in its src/ source file",
    )
    _require(
        _matches(record["address"], ADDRESS_RE), f"{path}.address", "must be an address"
    )
    _require(
        _matches(record["runtimeCodehash"], BYTES32_RE),
        f"{path}.runtimeCodehash",
        "must be bytes32",
    )
    _require(
        _matches(record["sourceCommit"], COMMIT_RE),
        f"{path}.sourceCommit",
        "must be a lowercase commit",
    )
    _deployment(record["deployment"], f"{path}.deployment")
    args = record["deployment"]["constructorArguments"]
    if contract_name == "EmergencySpellBatchFactoryV2":
        _require(
            args == "0x",
            f"{path}.deployment.constructorArguments",
            "factory constructor arguments must be empty",
        )
    elif kind != "infrastructure":
        _require(
            args != "0x",
            f"{path}.deployment.constructorArguments",
            "constructor arguments must not be empty",
        )
    for field in ("immutableReadbacks", "subjects", "parameters"):
        value = record[field]
        _require(isinstance(value, dict), f"{path}.{field}", "must be an object")
        for key, item in value.items():
            _require(
                _nonempty(key) and _nonempty(item),
                f"{path}.{field}.{key}",
                "must be a nonempty string",
            )
    required_readbacks = set() if kind == "infrastructure" else set(SPELL_BASE)
    if kind == "batch":
        required_readbacks.add("configHash()(bytes32)")
    _require(
        required_readbacks <= record["immutableReadbacks"].keys(),
        f"{path}.immutableReadbacks",
        "missing shared interface readbacks",
    )
    if kind in {"leaf", "registry-global"}:
        _require(
            bool(record["subjects"]),
            f"{path}.subjects",
            "spell must declare at least one emergency subject",
        )
    for field in ("subjects", "parameters"):
        for key, value in record[field].items():
            _require(
                key in record["immutableReadbacks"],
                f"{path}.{field}.{key}",
                "is not an immutable readback",
            )
            _require(
                value == record["immutableReadbacks"][key],
                f"{path}.{field}.{key}",
                "does not match immutable readback",
            )
    _object(record["reviews"], f"{path}.reviews", {"directUse", "batchUse"})
    _review(record["reviews"]["directUse"], f"{path}.reviews.directUse")
    _review(record["reviews"]["batchUse"], f"{path}.reviews.batchUse")
    _require(
        isinstance(record["batchEligible"], bool),
        f"{path}.batchEligible",
        "must be a boolean",
    )
    _require(
        record["operationalStatus"]
        in {"deployed", "reviewed", "incident-ready", "revoked", "superseded"},
        f"{path}.operationalStatus",
        "invalid status",
    )
    direct = record["reviews"]["directUse"]["status"]
    batch_use = record["reviews"]["batchUse"]["status"]
    if record["operationalStatus"] == "incident-ready":
        _require(
            direct == "approved",
            f"{path}.reviews.directUse.status",
            "incident-ready record must be approved",
        )
    if record["batchEligible"]:
        _require(
            record["kind"] == "leaf"
            and direct == "approved"
            and batch_use == "approved",
            f"{path}.batchEligible",
            "requires an approved leaf",
        )
    if batch_use == "approved":
        _require(
            record["kind"] == "leaf" and record["batchEligible"],
            f"{path}.reviews.batchUse.status",
            "approved batch use requires an eligible leaf",
        )
    if record["kind"] != "leaf":
        _require(
            not record["batchEligible"] and batch_use == "not-applicable",
            f"{path}.batchEligible",
            "non-leaf records cannot be batch eligible",
        )
    if record["kind"] == "batch":
        _batch(record["batch"], f"{path}.batch")
        batch = record["batch"]
        readbacks = batch["getterReadbacks"]
        simulation = batch["atomicSimulation"]
        _require(
            readbacks["label"] == batch["label"],
            f"{path}.batch.getterReadbacks.label",
            "does not match label",
        )
        _require(
            [x.lower() for x in readbacks["leaves"]]
            == [x.lower() for x in batch["leaves"]],
            f"{path}.batch.getterReadbacks.leaves",
            "does not match leaves",
        )
        _require(
            readbacks["configHash"] == batch["configHash"],
            f"{path}.batch.getterReadbacks.configHash",
            "does not match config hash",
        )
        _require(
            simulation["chainId"] == chain_id,
            f"{path}.batch.atomicSimulation.chainId",
            "does not match manifest",
        )
        _require(
            simulation["blockNumber"] >= record["deployment"]["blockNumber"],
            f"{path}.batch.atomicSimulation.blockNumber",
            "precedes deployment",
        )
        _require(
            simulation["batch"].lower() == record["address"].lower(),
            f"{path}.batch.atomicSimulation.batch",
            "does not match record",
        )
        _require(
            simulation["configHash"] == batch["configHash"],
            f"{path}.batch.atomicSimulation.configHash",
            "does not match batch",
        )
        if record["operationalStatus"] == "incident-ready":
            _require(
                batch["factoryEventVerified"],
                f"{path}.batch.factoryEventVerified",
                "must be true for incident-ready batch",
            )
            _require(
                simulation["status"] == "approved",
                f"{path}.batch.atomicSimulation.status",
                "must be approved",
            )
            for field in (
                "chiefAuthorizationVerified",
                "downstreamCallerVerified",
                "atomicRollbackVerified",
            ):
                _require(
                    simulation[field],
                    f"{path}.batch.atomicSimulation.{field}",
                    "must be true",
                )


def validate_manifest(manifest):
    _object(
        manifest, "manifest", {"schemaVersion", "chainId", "architecture", "records"}
    )
    _require(manifest["schemaVersion"] == 2, "manifest.schemaVersion", "must be 2")
    _require(
        _integer(manifest["chainId"]), "manifest.chainId", "must be a positive integer"
    )
    _require(
        manifest["architecture"] == "emergency-spells-v2",
        "manifest.architecture",
        "must be emergency-spells-v2",
    )
    _require(
        isinstance(manifest["records"], list), "manifest.records", "must be an array"
    )
    for index, record in enumerate(manifest["records"]):
        _record(record, manifest["chainId"], index)
    addresses = [record["address"].lower() for record in manifest["records"]]
    _require(
        len(addresses) == len(set(addresses)),
        "manifest.records",
        "contains duplicate addresses",
    )
    by_address = {record["address"].lower(): record for record in manifest["records"]}
    for index, record in enumerate(manifest["records"]):
        if record["kind"] != "batch":
            continue
        path = f"records[{index}].batch"
        factory = by_address.get(record["batch"]["factory"].lower())
        _require(
            factory is not None
            and factory["contractName"] == "EmergencySpellBatchFactoryV2"
            and factory["kind"] == "infrastructure",
            f"{path}.factory",
            "does not reference a factory record",
        )
        _require(
            factory["sourceCommit"] == record["sourceCommit"],
            f"{path}.factory",
            "source commit differs from batch",
        )
        _require(
            factory["deployment"]["blockNumber"] <= record["deployment"]["blockNumber"],
            f"{path}.factory",
            "factory was deployed after batch",
        )
        leaves = []
        for leaf_address in record["batch"]["leaves"]:
            leaf = by_address.get(leaf_address.lower())
            _require(
                leaf is not None and leaf["kind"] == "leaf",
                f"{path}.leaves",
                f"missing leaf {leaf_address}",
            )
            _require(
                leaf["deployment"]["blockNumber"]
                <= record["deployment"]["blockNumber"],
                f"{path}.leaves",
                f"leaf {leaf_address} was deployed after batch",
            )
            leaves.append(leaf)
        if record["operationalStatus"] == "incident-ready":
            _require(
                factory["operationalStatus"] == "incident-ready"
                and factory["reviews"]["directUse"]["status"] == "approved",
                f"{path}.factory",
                "factory is not incident-ready",
            )
            for leaf in leaves:
                ready = (
                    leaf["operationalStatus"] == "incident-ready"
                    and leaf["batchEligible"]
                    and leaf["reviews"]["directUse"]["status"] == "approved"
                    and leaf["reviews"]["batchUse"]["status"] == "approved"
                )
                _require(
                    ready,
                    f"{path}.leaves",
                    f"leaf {leaf['address']} is not incident-ready and batch eligible",
                )
    return by_address
