# Emergency Spells CLI

`cli/emergency-spells` validates deployment records, verifies deployed contracts, prepares and verifies batches, and inspects deployed batch contents. Run it from the repository root.

## Requirements

- Python 3.12 or newer;
- `cast`, `forge`, and `git` for commands that inspect live deployments;
- `ETH_RPC_URL` for every live-chain command.

The CLI uses only the Python standard library. Set `CAST`, `FORGE`, or `GIT` to override the corresponding executable name or path.

```sh
export ETH_RPC_URL=https://eth-mainnet.example
export CAST=cast
export FORGE=forge
export GIT=git
```

Use `cli/emergency-spells --help` or `cli/emergency-spells <command> --help` for the current command-line interface.

## Validate a V2 manifest

Validate the manifest schema, shared spell interface, review state, subject and parameter bindings, batch dependencies, deployment chronology, and lifecycle rules. This command does not access the network.

```sh
cli/emergency-spells validate-manifest \
  --manifest deployments/1/v2.json
```

## Validate V1 migration status

Reconcile the immutable V1 snapshot with the V2 manifest and the current migration overlay. This command does not access the network.

```sh
cli/emergency-spells validate-migration \
  --legacy deployments/1/legacy-v1.json \
  --v2-manifest deployments/1/v2.json \
  --migration deployments/1/v1-migration.json
```

## Verify a direct deployment

Verify a published leaf, registry-global spell, or batch factory against its creating transaction, receipt, runtime codehash, immutable readbacks, and exact signed source checkout.

The repository must be clean and checked out at the record's `sourceCommit`. Replace the example address with the published address being verified.

```sh
export ETH_RPC_URL=https://eth-mainnet.example

cli/emergency-spells verify-deployment \
  --manifest deployments/1/v2.json \
  --address 0x0000000000000000000000000000000000000001
```

Use `verify-batch` instead for a batch deployed through `EmergencySpellBatchFactoryV2`.

## Preflight a batch

Authenticate the factory and selected leaves before deployment, then calculate the configuration hash. `create2` additionally prints the predicted deterministic batch address.

Pass leaves as one quoted Foundry-style array. Preserve reviewed execution order for `create`; use strictly increasing address order for `create2` only when the actions are order-independent.

```sh
export ETH_RPC_URL=https://eth-mainnet.example

cli/emergency-spells preflight-batch \
  --manifest deployments/1/v2.json \
  --factory 0x0000000000000000000000000000000000000001 \
  --mode create2 \
  --label 'Incident batch' \
  --leaves '[0x0000000000000000000000000000000000000011,0x0000000000000000000000000000000000000022]'
```

Pass the printed configuration hash to the batch deployment script without changing the factory, mode, label, or leaf order.

## Verify a batch deployment

Verify the manifest configuration, factory deployment, selected leaf codehashes, constructor encoding, batch getters, factory call and event, receipt, and deterministic address when applicable.

```sh
export ETH_RPC_URL=https://eth-mainnet.example

cli/emergency-spells verify-batch \
  --manifest deployments/1/v2.json \
  --batch 0x0000000000000000000000000000000000000002 \
  --factory 0x0000000000000000000000000000000000000001 \
  --tx 0x0000000000000000000000000000000000000000000000000000000000000003 \
  --mode create2 \
  --label 'Incident batch' \
  --leaves '[0x0000000000000000000000000000000000000011,0x0000000000000000000000000000000000000022]'
```

The arguments must exactly match the published batch record.

## Inspect a deployed batch

Read the batch description and ordered leaf list from chain, then read each leaf description. Inspection is one level deep and preserves execution order.

```sh
export ETH_RPC_URL=https://eth-mainnet.example

cli/emergency-spells inspect-batch \
  --batch 0x0000000000000000000000000000000000000002
```

Example output:

```text
Emergency Spell | Batch: Incident batch (0x0000000000000000000000000000000000000002)
├── [0] Emergency Spell | Line Wipe: ETH-A (0x0000000000000000000000000000000000000011)
└── [1] Emergency Spell | OSM Stop: ETH-A (0x0000000000000000000000000000000000000022)
```

If a description or leaf-list read fails, the command prints every available node, marks unavailable data in the tree, and exits with status 1. Inspection is read-only and does not establish manifest publication, review status, batch eligibility, or incident readiness.

## Exit status

| Status | Meaning |
| --- | --- |
| `0` | Validation or inspection completed successfully. |
| `1` | Manifest validation, live-state verification, or inspection completeness failed. |
| `2` | Command usage is invalid or a required dependency is unavailable. |

Error details are written to standard error.

## Development

CLI tests are colocated with the Python sources and use only `unittest` from the standard library.

```sh
python3 -m compileall -q cli
python3 -m unittest discover -s cli/emergency_spells -t . -v
ruff check cli/emergency_spells
```

Format Markdown without wrapping prose:

```sh
prettier --write --prose-wrap never cli/README.md
```
