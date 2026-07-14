# V2 deployment scripts

V2 leaves and registry-global spells are deployed directly. The only shared deployment path is `EmergencySpellBatchFactoryV2`, which deploys reviewed batch configurations.

Run scripts with the reviewed source checkout, the intended RPC endpoint, and Foundry's normal signer configuration. Simulate before adding `--broadcast`. For example:

```sh
forge script script/clip-breaker/DeployClipBreakerV2.s.sol:ClipBreakerSpellV2DeployScript \
  --sig "run(address,address,bytes32)" <clipper-mom> <clip> <ilk> \
  --rpc-url <rpc-url>
```

Every script keeps a fully parameterized entrypoint for deployment before the applicable Chainlog entries exist. Post-hoc convenience entrypoints resolve only fixed, protocol-wide dependencies from Chainlog; variable subject addresses remain explicit.

Scripts and their colocated unit tests are organized by emergency subject:

| Subject       | Deployment source                                 |
| ------------- | ------------------------------------------------- |
| Line wipe     | `script/line-wipe/DeployLineWipeV2.s.sol`         |
| Clip breaker  | `script/clip-breaker/DeployClipBreakerV2.s.sol`   |
| OSM stop      | `script/osm-stop/DeployOsmStopV2.s.sol`           |
| DDM disable   | `script/ddm-disable/DeployDdmDisableV2.s.sol`     |
| Lite PSM halt | `script/lite-psm-halt/DeployLitePsmHaltV2.s.sol`  |
| SPBEAM halt   | `script/spbeam-halt/DeploySPBEAMHaltV2.s.sol`     |
| Splitter stop | `script/splitter-stop/DeploySplitterStopV2.s.sol` |
| stUSDS        | `script/stusds/DeployStUsdsV2.s.sol`              |
| Batch         | `script/batch/DeployEmergencySpellBatchV2.s.sol`  |

| Script contract | Fully parameterized | Chainlog-backed convenience |
| --- | --- | --- |
| `LineWipeSpellV2DeployScript` | `run(address,bytes32)` | `run(bytes32)` |
| `ClipBreakerSpellV2DeployScript` | `run(address,address,bytes32)` | `run(address,bytes32)` |
| `OsmStopSpellV2DeployScript` | `run(address,address,bytes32)` | `run(address,bytes32)` |
| `DdmDisableSpellV2DeployScript` | `run(address,address,bytes32)` | `run(address,bytes32)` |
| `LitePsmHaltSpellV2DeployScript` | `run(address,address,uint8)` | `runSell(address)`, `runBuy(address)`, `runBoth(address)` |
| `SPBEAMHaltSpellV2DeployScript` | `run(address,address)` | `run()` |
| `SplitterStopSpellV2DeployScript` | `run(address,address)` | `run()` |
| `StUsdsRateSetterDissBudSpellV2DeployScript` | `run(address,address,address)` | `run(address)` |
| `StUsdsRateSetterHaltSpellV2DeployScript` | `run(address,address)` | `run()` |
| `StUsdsWipeParamSpellV2DeployScript` | `run(address,address,address,uint8)` | `runCap()`, `runLine()`, `runBoth()` |
| `GlobalLineWipeSpellV2DeployScript` | `run(address,address)` | `run()` |
| `GlobalClipBreakerSpellV2DeployScript` | `run(address,address)` | `run()` |
| `GlobalOsmStopSpellV2DeployScript` | `run(address,address)` | `run()` |
| `EmergencySpellBatchFactoryV2DeployScript` | `run()` | Not applicable |
| `EmergencySpellBatchV2DeployScript` | `run(address,address[],string,bytes32)` | `run(address[],string,bytes32)` |
| `EmergencySpellBatchV2DeployScript` | `runDeterministic(address,address[],string,bytes32)` | `runDeterministic(address[],string,bytes32)` |
| `EmergencySpellBatchV2DeployScript` | `preview(address,address[],string)` | `preview(address[],string)` |

The explicit enum-bearing functions use ABI `uint8` values: `Flow` is `SELL = 0`, `BUY = 1`, and `BOTH = 2`; `Param` is `CAP = 0`, `LINE = 1`, and `BOTH = 2`. The convenience path uses named entrypoints instead. For example:

```sh
forge script script/lite-psm-halt/DeployLitePsmHaltV2.s.sol:LitePsmHaltSpellV2DeployScript \
  --sig "runBoth(address)" <lite-psm> \
  --rpc-url <rpc-url>

forge script script/stusds/DeployStUsdsV2.s.sol:StUsdsWipeParamSpellV2DeployScript \
  --sig "runLine()" \
  --rpc-url <rpc-url>
```

The convenience entrypoints use these fixed Chainlog keys:

| Spell family | Chainlog keys |
| --- | --- |
| Line wipe | `LINE_MOM` |
| Clip breaker | `CLIPPER_MOM` |
| OSM stop | `OSM_MOM` |
| DDM disable | `DIRECT_MOM` |
| Lite PSM halt | `LITE_PSM_MOM` |
| SPBEAM halt | `SPBEAM_MOM`, `MCD_SPBEAM` |
| Splitter stop | `SPLITTER_MOM`, `MCD_SPLIT` |
| stUSDS actions | `STUSDS_MOM`, `STUSDS_RATE_SETTER`, and, for wipe actions, `STUSDS` |
| Registry globals | `ILK_REGISTRY` and the applicable mom key |
| Batch deployment | `EMERGENCY_SPELL_BATCH_FAB` |

Use a convenience entrypoint only after every key it reads has been published in Chainlog. Otherwise, use the fully parameterized entrypoint; both paths deploy the same concrete contract constructor.

Before broadcasting a batch, run the preflight with the exact reviewed factory, label, and ordered leaves. Record its configuration hash:

```sh
export ETH_RPC_URL=<rpc-url>
cli/emergency-spells preflight-batch \
  --manifest deployments/<chain-id>/v2.json \
  --factory <factory> \
  --label <label> \
  --leaves '[<leaf>,<leaf>]'
```

Pass the printed configuration hash as the final deployment-script argument. The script rejects a leaf/label configuration that differs from the reviewed preflight output.

The factory uses `CREATE` and preserves the reviewed leaf order. Do not sort the leaves. Repeated deployment of the same configuration is allowed and produces a different address.

After a direct leaf, global, or factory deployment, generate a record draft from the deployment transaction:

```sh
cli/emergency-spells draft-deployment \
  --artifact <src/path/Contract.sol:Contract> \
  --kind <leaf|registry-global|infrastructure> \
  --tx <deployment-tx> \
  --subjects '[<getter-signature>]' \
  --params '[]' \
  --readbacks '[<getter-signature>]'
```

For a factory-created batch, generate the record from the factory transaction and the manifest's published factory and leaves:

```sh
cli/emergency-spells draft-batch \
  --manifest deployments/<chain-id>/v2.json \
  --factory <factory> \
  --tx <deployment-tx> \
  --label <label> \
  --leaves '[<leaf>,<leaf>]'
```

Both commands print JSON to standard output and never edit the manifest. Redirect the draft to a temporary file, review it, add it to `records`, and complete its review evidence. Batch drafts also require the atomic-simulation placeholders to be completed. Raw drafts are intentionally invalid until this review work is done.

Run the general deployment validator after publishing a direct record. For a factory-created batch, run the batch-specific post-deployment validator instead:

```sh
cli/emergency-spells verify-deployment \
  --manifest deployments/<chain-id>/v2.json \
  --address <deployed-address>

cli/emergency-spells verify-batch \
  --manifest deployments/<chain-id>/v2.json \
  --batch <batch> \
  --factory <factory> \
  --tx <deployment-tx> \
  --label <label> \
  --leaves '[<leaf>,<leaf>]'
```

Inspect a deployed batch and its leaves directly from chain:

```sh
cli/emergency-spells inspect-batch --batch <batch>
```

Inspection preserves execution order and displays every available description and address. An incomplete read produces a partial tree and exits nonzero. This command does not establish manifest publication, review status, or batch eligibility.

A successful deployment or factory event is not incident-response approval. The manifest must contain the applicable review and structured simulation attestation. The validators bind that attestation to the configuration but do not replay or truth-test its external trace; reviewers must verify the evidence criteria in [`deployments/README.md`](../deployments/README.md).

Run the validator from a clean repository whose build inputs match the record's signed `sourceCommit`. Documentation and manifest commits may follow that source commit, but `src/`, `foundry.toml`, `.gitmodules`, `lib/`, and `remappings.txt` must remain unchanged. Before incident use, fetch and verify the latest canonical signed manifest commit and record it in the incident log. See [`deployments/README.md`](../deployments/README.md) for the complete publication workflow, status transitions, and manual publication/revocation boundary.

The CLI requires Python 3.12 or newer and has no Python package dependencies. It invokes `cast`, `forge`, and `git` as subprocesses; `CAST`, `FORGE`, and `GIT` can override those executable names when required by the environment.

See the [`cli/` reference](../cli/README.md) for prerequisites, exit statuses, and examples for every command.
