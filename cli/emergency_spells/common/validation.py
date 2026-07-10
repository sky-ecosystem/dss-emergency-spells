import re


ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
BYTES32_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
BYTES_RE = re.compile(r"^0x(?:[0-9a-fA-F]{2})*$")


class ValidationError(Exception):
    pass


class DependencyError(Exception):
    pass


def fail(path, message):
    raise ValidationError(f"{path}: {message}")


def require(condition, path, message):
    if not condition:
        fail(path, message)


def object_(value, path, keys):
    require(isinstance(value, dict), path, "must be an object")
    missing = set(keys) - value.keys()
    extra = value.keys() - set(keys)
    require(not missing, path, f"missing fields: {', '.join(sorted(missing))}")
    require(not extra, path, f"unexpected fields: {', '.join(sorted(extra))}")


def nonempty(value):
    return isinstance(value, str) and bool(value)


def integer(value):
    return isinstance(value, int) and not isinstance(value, bool) and value >= 1


def matches(value, pattern):
    return isinstance(value, str) and pattern.fullmatch(value) is not None
