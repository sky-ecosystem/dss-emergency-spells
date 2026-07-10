# V2 deployment scripts

V2 leaves and registry-global spells are deployed directly. The only shared
deployment path is `EmergencySpellBatchFactoryV2`, which deploys reviewed batch
configurations.

Run scripts with the reviewed source checkout, the intended RPC endpoint, and
Foundry's normal signer configuration. Simulate before adding `--broadcast`.
For example:

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
| `EmergencySpellBatchV2DeployScript` | `run(address,address[],string,bool)` |

`Flow` values are `SELL = 0`, `BUY = 1`, and `BOTH = 2`. `Param` values are
`CAP = 0`, `LINE = 1`, and `BOTH = 2`.

Before broadcasting a batch, run:

```sh
scripts/validate-v2-batch-preflight.sh \
  deployments/<chain-id>/v2.json <rpc-url> <create|create2> <leaf> [leaf ...]
```

After any deployment, add the reviewed record to the V2 manifest and run the
general deployment validator. For a batch, also run the batch-specific
post-deployment validator:

```sh
scripts/validate-v2-deployment.sh \
  deployments/<chain-id>/v2.json <rpc-url> <deployed-address>

scripts/validate-v2-batch-postdeploy.sh \
  deployments/<chain-id>/v2.json <rpc-url> <batch> <factory> <deployment-tx> \
  <create|create2> <label> <leaf> [leaf ...]
```

A successful deployment or factory event is not incident-response approval.
The manifest must contain the applicable review and simulation evidence.
