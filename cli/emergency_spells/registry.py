from .common import ADDRESS_RE, ValidationError


def _parse_uint(value, context):
    try:
        return int(value, 0)
    except (TypeError, ValueError) as error:
        raise ValidationError(f"{context}: must be an unsigned integer") from error


def _safe_ranges(entries):
    ranges = []
    start = None
    for entry in entries:
        if entry["error"] is None and start is None:
            start = entry["index"]
        if entry["error"] is not None and start is not None:
            ranges.append((start, entry["index"] - 1))
            start = None
    if start is not None:
        ranges.append((start, len(entries) - 1))
    return ranges


def diagnose_registry(spell_address, rpc_url, runner):
    if ADDRESS_RE.fullmatch(spell_address) is None:
        raise ValidationError("spell: must be an address")

    block = _parse_uint(
        runner.run("cast", "block-number", "--rpc-url", rpc_url), "block number"
    )
    block_argument = str(block)
    registry = runner.run(
        "cast",
        "call",
        spell_address,
        "ilkRegistry()(address)",
        "--rpc-url",
        rpc_url,
        "--block",
        block_argument,
    )
    if ADDRESS_RE.fullmatch(registry) is None:
        raise ValidationError("ilkRegistry(): must return an address")
    count = _parse_uint(
        runner.run(
            "cast",
            "call",
            registry,
            "count()(uint256)",
            "--rpc-url",
            rpc_url,
            "--block",
            block_argument,
        ),
        "registry count",
    )

    entries = []
    for index in range(count):
        error = None
        try:
            runner.run(
                "cast",
                "call",
                spell_address,
                "scheduleRange(uint256,uint256)",
                str(index),
                str(index),
                "--rpc-url",
                rpc_url,
                "--block",
                block_argument,
            )
        except ValidationError as failure:
            error = " ".join(str(failure).split())
        entries.append({"index": index, "error": error})

    return {
        "spell": spell_address,
        "registry": registry,
        "block": block,
        "entries": entries,
        "safeRanges": _safe_ranges(entries),
    }
