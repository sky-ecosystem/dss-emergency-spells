import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any


ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
BYTES32_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
BYTES_RE = re.compile(r"^0x(?:[0-9a-fA-F]{2})*$")


class ValidationError(Exception):
    pass


class DependencyError(Exception):
    pass


def parse_leaves(value: str) -> list[str]:
    if not value.startswith("[") or not value.endswith("]"):
        raise ValidationError("--leaves must be a bracketed address array")
    body = value[1:-1].strip()
    if not body:
        raise ValidationError("--leaves must not be empty")
    leaves = [leaf.strip() for leaf in body.split(",")]
    if any(not leaf or not ADDRESS_RE.fullmatch(leaf) for leaf in leaves):
        raise ValidationError("--leaves contains an invalid address")
    return leaves


def require_rpc_url() -> str:
    value = os.environ.get("ETH_RPC_URL", "")
    if not value:
        raise DependencyError("ETH_RPC_URL is required")
    return value


def load_json(path: str | Path) -> Any:
    try:
        with Path(path).open(encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise ValidationError(f"cannot read JSON file {path}: {error}") from error


class Runner:
    def __init__(self, root: Path):
        self.root = root

    def run(self, tool: str, *arguments: str) -> str:
        executable = os.environ.get(tool.upper(), tool)
        try:
            result = subprocess.run(
                [executable, *arguments],
                cwd=self.root,
                check=True,
                capture_output=True,
                text=True,
            )
        except FileNotFoundError as error:
            raise DependencyError(f"{executable} is required") from error
        except subprocess.CalledProcessError as error:
            detail = (
                error.stderr.strip()
                or error.stdout.strip()
                or f"exit {error.returncode}"
            )
            raise ValidationError(f"{tool} failed: {detail}") from error
        return result.stdout.strip()
