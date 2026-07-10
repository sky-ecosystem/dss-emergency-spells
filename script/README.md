# V2 deployment scripts

V2 leaves and registry-global spells are deployed directly. The only shared deployment path is `EmergencySpellBatchFactoryV2`, which deploys reviewed batch configurations.

Run scripts with the reviewed source checkout, the intended RPC endpoint, and Foundry's normal signer configuration. Simulate before adding `--broadcast`. For example:

```sh
forge script script/DeployV2.s.sol:ClipBreakerSpellV2DeployScript \
  --sig "run(address,address,bytes32)" <clipper-mom> <clip> <ilk> \
  --rpc-url <rpc-url>
```

The available script contracts and `run` signatures are:

| Script contract | Signature |
| --- | --- |
| `LineWipeSpellV2DeployScript` | `run(address,bytes32)` |
| `ClipBreakerSpellV2DeployScript` | `run(address,address,bytes32)` |
| `OsmStopSpellV2DeployScript` | `run(address,address,bytes32)` |
| `DdmDisableSpellV2DeployScript` | `run(address,address,bytes32)` |
| `LitePsmHaltSpellV2DeployScript` | `run(address,address,uint8)` |
| `SPBEAMHaltSpellV2DeployScript` | `run(address,address)` |
| `SplitterStopSpellV2DeployScript` | `run(address,address)` |
| `StUsdsRateSetterDissBudSpellV2DeployScript` | `run(address,address,address)` |
| `StUsdsRateSetterHaltSpellV2DeployScript` | `run(address,address)` |
| `StUsdsWipeParamSpellV2DeployScript` | `run(address,address,address,uint8)` |
| `GlobalLineWipeSpellV2DeployScript` | `run(address,address)` |
| `GlobalClipBreakerSpellV2DeployScript` | `run(address,address)` |
| `GlobalOsmStopSpellV2DeployScript` | `run(address,address)` |
| `EmergencySpellBatchFactoryV2DeployScript` | `run()` |
| `EmergencySpellBatchV2DeployScript` | `run(address,address[],string,bytes32)` for `CREATE` |
| `EmergencySpellBatchV2DeployScript` | `runDeterministic(address,address[],string,bytes32)` for `CREATE2` |

`Flow` values are `SELL = 0`, `BUY = 1`, and `BOTH = 2`. `Param` values are `CAP = 0`, `LINE = 1`, and `BOTH = 2`.

Before broadcasting a batch, run the preflight with the exact reviewed factory, label, mode, and ordered leaves. Record its configuration hash and, for `CREATE2`, its predicted address:

```sh
cli/validate-v2-batch-preflight.sh \
  deployments/<chain-id>/v2.json <rpc-url> <source-root> <factory> \
  <create|create2> <label> <leaf> [leaf ...]
```

Pass the printed configuration hash as the final deployment-script argument. The script rejects a leaf/label configuration that differs from the reviewed preflight output.

Use `CREATE2` only when the selected actions are order-independent and the leaf addresses have already been placed in strictly increasing order. Use `CREATE` when execution order is semantically meaningful; it preserves the reviewed order. Never sort a meaningful action sequence merely to make it deterministic.

After a direct leaf, global, or factory deployment, add the reviewed record to the V2 manifest and run the general deployment validator. For a factory-created batch, run the batch-specific post-deployment validator instead:

```sh
cli/validate-v2-deployment.sh \
  deployments/<chain-id>/v2.json <rpc-url> <source-root> <deployed-address>

cli/validate-v2-batch-postdeploy.sh \
  deployments/<chain-id>/v2.json <rpc-url> <source-root> <batch> <factory> \
  <deployment-tx> <create|create2> <label> <leaf> [leaf ...]
```

A successful deployment or factory event is not incident-response approval. The manifest must contain the applicable review and structured simulation attestation. The validators bind that attestation to the configuration but do not replay or truth-test its external trace; reviewers must verify the evidence criteria in [`deployments/README.md`](../deployments/README.md).

Run the latest canonical signed CLI and pass a separate clean `source-root` checked out at the record's exact signed `sourceCommit`. Before incident use, fetch and verify the latest canonical signed manifest commit and record it in the incident log. See [`deployments/README.md`](../deployments/README.md) for status transitions and the manual publication/revocation boundary.
