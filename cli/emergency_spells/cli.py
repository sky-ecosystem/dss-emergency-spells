import argparse
import sys
from pathlib import Path

from .batch import preflight_batch, verify_batch
from .common import (
    DependencyError,
    Runner,
    ValidationError,
    load_json,
    parse_leaves,
    require_rpc_url,
)
from .deployment import verify_deployment
from .manifest import validate_manifest
from .migration import validate_migration


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
    migration.add_argument("--v2-manifest", required=True)
    migration.add_argument("--migration", required=True)

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
    return parser


def _batch_arguments(parser, include_deployment):
    parser.add_argument("--manifest", required=True)
    if include_deployment:
        parser.add_argument("--batch", required=True)
    parser.add_argument("--factory", required=True)
    if include_deployment:
        parser.add_argument("--tx", required=True)
    parser.add_argument("--mode", required=True, choices=("create", "create2"))
    parser.add_argument("--label", required=True)
    parser.add_argument("--leaves", required=True, help="Foundry-style address array")


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
            arguments.mode,
            arguments.label,
            leaves,
            rpc_url,
            runner,
            ROOT,
        )
        print(
            f"Validated V2 batch preflight: {len(leaves)} leaf/leaves ({arguments.mode})"
        )
        print(f"Config hash: {result['configHash']}")
        if "predictedBatch" in result:
            print(f"Predicted batch: {result['predictedBatch']}")
        return
    verify_batch(
        manifest,
        arguments.batch,
        arguments.factory,
        arguments.tx,
        arguments.mode,
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
