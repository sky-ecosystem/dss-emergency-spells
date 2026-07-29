import argparse
import json
import sys
from pathlib import Path

from .batch import inspect_batch, preflight_batch, verify_batch
from .common import (
    DependencyError,
    Runner,
    ValidationError,
    load_json,
    parse_leaves,
    parse_string_array,
    require_rpc_url,
)
from .common.deployment import verify_deployment
from .common.manifest import validate_manifest
from .draft import draft_batch, draft_deployment
from .migration import validate_migration
from .registry import probe_registry


ROOT = Path(__file__).resolve().parents[2]


def _parser():
    parser = argparse.ArgumentParser(prog="emergency-spells")
    commands = parser.add_subparsers(dest="command", required=True)

    manifest = commands.add_parser(
        "validate-manifest", help="validate a V2 deployment manifest"
    )
    manifest.add_argument("--manifest", required=True)

    migration = commands.add_parser(
        "validate-migration", help="validate V1 migration status"
    )
    migration.add_argument("--legacy", required=True)
    migration.add_argument("--v2-manifest", "--v2", required=True)
    migration.add_argument("--migration", "--mig", required=True)

    deployment = commands.add_parser(
        "verify-deployment", help="verify a direct deployment"
    )
    deployment.add_argument("--manifest", required=True)
    deployment.add_argument("--address", required=True)

    preflight = commands.add_parser(
        "preflight-batch", help="validate a batch before deployment"
    )
    _batch_arguments(preflight, include_deployment=False)

    batch = commands.add_parser("verify-batch", help="verify a deployed batch")
    _batch_arguments(batch, include_deployment=True)

    inspection = commands.add_parser(
        "inspect-batch", help="show a deployed batch and its leaves"
    )
    inspection.add_argument("--batch", required=True)

    registry = commands.add_parser(
        "probe-registry", help="identify failing registry-global entries"
    )
    registry.add_argument("--spell", required=True)

    draft = commands.add_parser(
        "draft-deployment", help="generate a direct deployment record draft"
    )
    draft.add_argument("--artifact", required=True)
    draft.add_argument(
        "--kind",
        required=True,
        choices=("leaf", "registry-global", "infrastructure"),
    )
    draft.add_argument(
        "--transaction-hash", "--tx", dest="transaction_hash", required=True
    )
    draft.add_argument("--subjects", default="[]")
    draft.add_argument("--parameters", "--params", default="[]")
    draft.add_argument(
        "--immutable-readbacks",
        "--readbacks",
        dest="immutable_readbacks",
        default="[]",
    )

    batch_draft = commands.add_parser(
        "draft-batch", help="generate a batch deployment record draft"
    )
    batch_draft.add_argument("--manifest", required=True)
    batch_draft.add_argument("--factory", required=True)
    batch_draft.add_argument(
        "--transaction-hash", "--tx", dest="transaction_hash", required=True
    )
    batch_draft.add_argument("--label", required=True)
    batch_draft.add_argument(
        "--leaves",
        required=True,
        help="Foundry-style address array",
    )
    return parser


def _batch_arguments(parser, include_deployment):
    parser.add_argument("--manifest", required=True)
    if include_deployment:
        parser.add_argument("--batch", required=True)
    parser.add_argument("--factory", required=True)
    if include_deployment:
        parser.add_argument(
            "--transaction-hash", "--tx", dest="transaction_hash", required=True
        )
    parser.add_argument("--label", required=True)
    parser.add_argument(
        "--leaves",
        required=True,
        help="Foundry-style address array",
    )


def _display_description(description):
    if description is None:
        return "[description unavailable]"
    return json.dumps(description, ensure_ascii=False)[1:-1]


def _render_batch_inspection(result):
    print(f"{_display_description(result['description'])} ({result['address']})")
    if result["leaves_unavailable"]:
        print("└── [leaves unavailable]")
        return
    if not result["leaves"]:
        print("└── [no leaves]")
        return
    last = len(result["leaves"]) - 1
    for index, leaf in enumerate(result["leaves"]):
        branch = "└──" if index == last else "├──"
        print(
            f"{branch} [{index}] {_display_description(leaf['description'])} ({leaf['address']})"
        )


def _render_registry_probe(result):
    print(f"Registry probe at block {result['block']}")
    print(result["spell"])
    print(f"Registry: {result['registry']}")
    if not result["entries"]:
        print("└── [empty registry]")
        return
    last = len(result["entries"]) - 1
    for position, entry in enumerate(result["entries"]):
        branch = "└──" if position == last else "├──"
        status = "PASS" if entry["error"] is None else f"FAIL: {entry['error']}"
        print(f"{branch} [{entry['index']}] {status}")
    ranges = ", ".join(
        f"[{start}, {end}]" for start, end in result["safeRanges"]
    )
    print(f"Safe ranges: {ranges or 'none'}")


def _execute(arguments, runner):
    command = arguments.command
    if command == "validate-manifest":
        validate_manifest(load_json(arguments.manifest))
        print(f"Validated V2 manifest: {arguments.manifest}")
        return
    if command == "validate-migration":
        validate_migration(
            load_json(arguments.legacy),
            load_json(arguments.v2_manifest),
            load_json(arguments.migration),
        )
        print(f"Validated V1 migration status: {arguments.migration}")
        return

    if command == "inspect-batch":
        result = inspect_batch(arguments.batch, require_rpc_url(), runner)
        _render_batch_inspection(result)
        if result["errors"]:
            raise ValidationError(
                "batch inspection incomplete: " + "; ".join(result["errors"])
            )
        return

    if command == "probe-registry":
        result = probe_registry(arguments.spell, require_rpc_url(), runner)
        _render_registry_probe(result)
        failures = [
            str(entry["index"])
            for entry in result["entries"]
            if entry["error"] is not None
        ]
        if failures:
            noun = "entry" if len(failures) == 1 else "entries"
            raise ValidationError(
                f"registry probe found {len(failures)} failing registry {noun}: "
                + ", ".join(failures)
            )
        return

    if command == "draft-deployment":
        result = draft_deployment(
            artifact=arguments.artifact,
            kind=arguments.kind,
            transaction_hash=arguments.transaction_hash,
            subjects=parse_string_array(arguments.subjects, "--subjects"),
            parameters=parse_string_array(arguments.parameters, "--parameters"),
            immutable_readbacks=parse_string_array(
                arguments.immutable_readbacks, "--immutable-readbacks"
            ),
            rpc_url=require_rpc_url(),
            runner=runner,
            root=ROOT,
        )
        print(json.dumps(result, indent=2))
        return

    if command == "draft-batch":
        result = draft_batch(
            manifest=load_json(arguments.manifest),
            factory_address=arguments.factory,
            transaction_hash=arguments.transaction_hash,
            label=arguments.label,
            leaves=parse_leaves(arguments.leaves),
            rpc_url=require_rpc_url(),
            runner=runner,
            root=ROOT,
        )
        print(json.dumps(result, indent=2))
        return

    manifest = load_json(arguments.manifest)
    rpc_url = require_rpc_url()
    if command == "verify-deployment":
        verify_deployment(manifest, arguments.address, rpc_url, runner, ROOT)
        print(f"Validated V2 deployment: {arguments.address}")
        return

    leaves = parse_leaves(arguments.leaves)
    if command == "preflight-batch":
        result = preflight_batch(
            manifest,
            arguments.factory,
            arguments.label,
            leaves,
            rpc_url,
            runner,
            ROOT,
        )
        print(
            f"Validated V2 batch preflight: {len(leaves)} leaf/leaves"
        )
        print(f"Config hash: {result['configHash']}")
        return
    verify_batch(
        manifest,
        arguments.batch,
        arguments.factory,
        arguments.transaction_hash,
        arguments.label,
        leaves,
        rpc_url,
        runner,
        ROOT,
    )
    print(f"Validated V2 batch deployment: {arguments.batch}")
    print(
        "Validated the configuration-bound simulation attestation; reviewers must verify its external trace."
    )


def main(argv=None):
    arguments = _parser().parse_args(argv)
    try:
        _execute(arguments, Runner(ROOT))
    except DependencyError as error:
        print(f"emergency-spells: {error}", file=sys.stderr)
        return 2
    except ValidationError as error:
        print(f"emergency-spells: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
