# Maker Protocol Emergency Spells

Pre-deployed spells to allow MakerDAO Governance to react faster in case of emergencies.

## Motivation

In Maker's linguo, a spell is a bespoke smart contract to execute authorized actions in Maker Protocol on behalf on
Maker Governance.

Since most contracts in Maker Protocol follow a [simple, battle-tested authorization scheme][auth], with an "all or
nothing" approach, it means that every spell has _root_ access to every single of its components.

[auth]: https://github.com/makerdao/pe-checklists/blob/master/core/standards.md#permissions

In order to mitigate the risks associated with that design decision, the spell process is quite "heavy", where
multiple trusted parties are involved, and with comprehensive [checklists][spell-checklists] that must be strictly
followed.

[spell-checklists]: https://github.com/makerdao/pe-checklists/tree/master/spell

With all the complexity and coordination effort, it is not a surprise that it takes a long time for a spell to be
successfully crafted, reviewed and handed over to Maker Governance. As per the [current process][spell-schedule], with
the involvement of at least 3 engineers from the different EAs in the Spell Team, not to mention the Governance
Facilitators and other key stakeholders, it takes at least 8 working days to deliver a regular spell.

[spell-schedule]: https://github.com/makerdao/pe-checklists/blob/master/spell/spell-crafter-mainnet-workflow.md#spell-coordination-schedule

For emergency spells, historically the agreed SLA had been 24h. That was somehow possible when there was a single
tight-knit team working on spells, however can be specially challenging with a more decentralized workforce, which is
scattered around the world. Even if it was still possible to meet that SLA, in some situations 24h might be too much
time.

This repository contains a couple of different spells performing emergency actions that can be pre-deployed to allow
MakerDAO Governance to quickly respond to incidents, without the need for dedicated engineers to chime in and craft a
bespoke spell in record time.

## Deployments

### Standalone Spells

#### `SPBEAMHaltSpell`

```
0xDECF4A7E4b9CAa3c3751D163866941a888618Ac0
```

#### `SplitterStopSpell`

```
0x12531afC02aC18a9597Cfe8a889b7B948243a60b
```

#### `MultiClipBreakerSpell`

```
0x828824dBC62Fba126C76E0Abe79AE28E5393C2cb
```

#### `MultiLineWipeSpell`

```
0x4B5f856B59448304585C2AA009802A16946DDb0f
```

#### `MultiOsmStopSpell`

```
0x3021dEdB0bC677F43A23Fcd1dE91A07e5195BaE8
```

### On-chain Emergency Spell Factories

| Name                        | Address                                      |
| --------------------------- | -------------------------------------------- |
| `GroupedClipBreakerFactory` | `0x867852d30bb3cb1411fb4e404fae28ef742b1023` |
| `GroupedLineWipeFactory`    | `0x8646f8778b58a0df118facedf522181ba7277529` |
| `SingleDdmDisableFactory`   | `0x8BA0f6C4009Ea915706e1bCfB1d879E34587dC69` |
| `SingleOsmStopFactory`      | `0x83211c74131bA2B3de7538f588f1c2f309e81eF0` |
| `SingleLitePsmHaltFactory`  | `0xB261b73698F6dBC03cB1E998A3176bdD81C3514A` |

#### `GroupedClipBreakerSpell`

| Ilks                         | Address                                      |
| ---------------------------- | -------------------------------------------- |
| `ETH-A`, `ETH-B,` `ETH-C`    | `0x7d50528DE0F6117dA4e7bDC3dc15EDF78f8f175f` |
| `LSE-MKR-A`                  | `0xc75Bc88b5d1A220E982AabAd3142f75B14D0009b` |
| `WBTC-A`, `WBTC-B`, `WBTC-C` | `0x8d1E22d6490FEf486309C6430140b9f1f12D31ED` |
| `WSTETH-A`, `WSTETH-B`       | `0xa383fF9F207202A7A4C750E2395B8793f9D2Ff84` |

#### [DEPRECATED] `SingleClipBreakerSpell`

| Ilk             | Address                                          |
| --------------- | ------------------------------------------------ |
| ~~`ETH-A`~~     | ~~`0xa1122011E26d160b263295476e294A17560213D1`~~ |
| ~~`ETH-B`~~     | ~~`0x1efe035022c63ACB53f3662bcb18683F522d2811`~~ |
| ~~`ETH-C`~~     | ~~`0xDef93051a647C5c3C5ce0B32C32B4394b4a55a85`~~ |
| ~~`LSE-MKR-A`~~ | ~~`0x9CF8Bd21814B57b9Ca5B368efb00A551682b7823`~~ |
| ~~`WBTC-A`~~    | ~~`0x43Aa7ED6BA07274104f5Ea0e08E6C236B02Bc636`~~ |
| ~~`WBTC-B`~~    | ~~`0x0ffE29C34da1C4760a1409DE19045a5ca41a7912`~~ |
| ~~`WBTC-C`~~    | ~~`0x9d5F59D4a599888E77899Afa8cc4bEd2334557d3`~~ |
| ~~`WSTETH-A`~~  | ~~`0x4e95dBC199c52F3Fb6Cfff1514099fF6A3942E56`~~ |
| ~~`WSTETH-B`~~  | ~~`0x052eDfA59F7eA13f27B0E886a0f89e88BA7b7Ea3`~~ |

#### `SingleDdmDisableSpell`

| Ilk                         | Address                                      |
| --------------------------- | -------------------------------------------- |
| `DIRECT-SPARK-DAI`          | `0xf10d37FC47e966508A62d4874dC69c7Ed62fd11B` |
| `DIRECT-SPARK-MORPHO-DAI`   | `0xD6513162b30D0BEC7e9E81c4F2Ce2C07d7D2a372` |
| `DIRECT-SPK-AAVE-LIDO-USDS` | `0x36cbC441C671f75BB5aE1150b12106D1D921d53c` |

#### `GroupedLineWipeSpell`

| Ilks                                                                                                    | Address                                      |
| ------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `ALLOCATOR-SPARK-A`                                                                                     | `0x68220D37eA40A60ACDa21cb607085225280dc2DB` |
| `ALLOCATOR-BLOOM-A`                                                                                     | `0xd12Aebe605b37391F8741C2C10A32D4Fa6A9D544` |
| `ALLOCATOR-NOVA-A`                                                                                      | `0x401702b6B6fEEb4C19658e178B8cAa90d96E94D3` |
| `ALLOCATOR-OBEX-A`                                                                                      | `0x2113592be9e40318C87320c36ba1eEAc9522ee3e` |
| `ALLOCATOR-PATTERN-A`                                                                                   | `0x65231a74915fc154DC84Ac7a067B4835C8D049bF` |
| `ALLOCATOR-SPARK-A`, `ALLOCATOR-BLOOM-A`, `ALLOCATOR-NOVA-A`, `ALLOCATOR-OBEX-A`, `ALLOCATOR-PATTERN-A` | `0x9356724264cBFA5A1a03C4C2817adADD790a2f6F` |
| `ETH-A`, `ETH-B`, `ETH-C`                                                                               | `0x07bc4A6F65A7965856aFff5af67a702220367d5f` |
| `WBTC-A`, `WBTC-B`, `WBTC-C`                                                                            | `0xC9c4e0C7F769Ec16a39e3fc016e2A4Dc639EAa74` |
| `WSTETH-A`, `WSTETH-B`                                                                                  | `0x1a1F368e99F22dED25ECfeA2A87a7590771b6ED0` |

#### [DEPRECATED] ~~SingleLineWipeSpell`~~

| Ilk                     | Address                                          |
| ----------------------- | ------------------------------------------------ |
| ~~`ALLOCATOR-SPARK-A`~~ | ~~`0xFaF2Cd3a76EBEFB257BE0ea7dF5D222acDDA6734`~~ |
| ~~`ETH-A`~~             | ~~`0x46BAeb8fb770f9bcfb5cF9A696F80fcEe6D0dcfE`~~ |
| ~~`ETH-B`~~             | ~~`0x9E8516f7Ba14429917343c7Bc4c9d7378d298DDF`~~ |
| ~~`ETH-C`~~             | ~~`0x0b6D27cf223D6e9ED2e55D5ADcF1909bbcEcFA32`~~ |
| ~~`LSE-MKR-A`~~         | ~~`0xeeb0D6bdBa6b74E1813C8e8AAD3c927e5d86F87D`~~ |
| ~~`RWA001-A`~~          | ~~`0xE4bcBe6a8A4564c9C7ECED4F5a827cc106352602`~~ |
| ~~`RWA002-A`~~          | ~~`0x944F013edF4886bD0871391EFFc98911B8F0821f`~~ |
| ~~`RWA009-A`~~          | ~~`0x46cbB3f96cC07205Dc8EE495615f144E288c8815`~~ |
| ~~`RWA012-A`~~          | ~~`0xd9314ff8f9DCB2e7C1434155800B54d02Ae7f6f5`~~ |
| ~~`RWA013-A`~~          | ~~`0x4ed518908dF1BD4b1C8a48602e4FADf2Fd248D9f`~~ |
| ~~`RWA015-A`~~          | ~~`0x9A0A0700253cBb7372E3A6659fb8Be11866F32FA`~~ |
| ~~`WBTC-A`~~            | ~~`0xd960050a502A27bBF33228E033782CB35B72e74D`~~ |
| ~~`WBTC-B`~~            | ~~`0x47f20D5e95D8477a9dF2D483414Bce28b87B10Eb`~~ |
| ~~`WBTC-C`~~            | ~~`0x1BC7cA708d882a82bdB1ade4838BeDB90144127c`~~ |
| ~~`WSTETH-A`~~          | ~~`0x6A7710534E840a64ba709775ab9F23a6894bECa4`~~ |
| ~~`WSTETH-B`~~          | ~~`0x79D7e31520FCD7bB5bf25fa13b2028cB5a32699D`~~ |

#### `SingleLitePsmHaltSpell`

| Ilk                    | Flow   | Address                                      |
| ---------------------- | ----   | ------------------------------------------   |
| `LITE-PSM-USDC-A`      | `BOTH` | `0x83Ff10f34076293Ea354Ba2Bef1374bBad023B73` |
| `LITE-PSM-USDC-A`      | `BUY`  | `0xBFd0B1ae2698E5567cd07A62c217114457B81EDD` |
| `LITE-PSM-USDC-A`      | `SELL` | `0x1573C9Cb707e3031115b6b7cD1cd4ED34906b7A3` |

#### `SingleOsmStopSpell`

| Ilk         | Address                                      |
| ----------- | -------------------------------------------- |
| `ETH-A`     | `0x3a03F35ba1F5e015a288feD50cEB5342d4989E85` |
| `ETH-B`     | `0xb5f5F6CdCddD391402a2E71c2380d2f64372c49B` |
| `ETH-C`     | `0x690a6a9236E80Bd331e635Ad696be45C89a418ec` |
| `LSE-MKR-A` | `0x9a4039d5abeDa765A3B295c51Db511861428109a` |
| `WBTC-A`    | `0xa1295912d6b535e30Df9aE4077256d0A989F4863` |
| `WBTC-B`    | `0x3eC627D7A4F5b88cD13E67d55885B0Bf09B4a3b0` |
| `WBTC-C`    | `0x3d045508697681F021980B41759CDB8aB5C5AFb8` |
| `WSTETH-A`  | `0xC8F4544334B9ACBcd6DDE5c2283d53b48ad762BC` |
| `WSTETH-B`  | `0xD1ce9F89c7f1e6Ec698bc840676efbFfC1373daa` |

#### `StUsdsRateSetterDissBudSpell`

| Ilk         | Address                                      |
| ----------- | -------------------------------------------- |
| `stUSDS`     | `<TBD>` |

#### `StUsdsRateSetterHaltSpell`

| Ilk         | Address                                      |
| ----------- | -------------------------------------------- |
| `stUSDS`     | `<TBD>` |

#### `StUsdsWipeParamSpell`

| Ilk                    | Flow   | Address                                      |
| ---------------------- | ----   | ------------------------------------------   |
| `stUSDS`      | `BOTH` | `<TBD>` |
| `stUSDS`      | `CAP`  | `<TBD>` |
| `stUSDS`      | `LINE` | `<TBD>` |

## Implemented Actions

| Description        | Single-ilk         | Grouped            | Multi-ilk / Global |
| :----------        | :--------:         | :-----:            | :----------------: |
| Wipe `line`        | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Set `Clip` breaker | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Disable `DDM`      | :white_check_mark: | :x:                | :x:                |
| Stop `OSM`         | :white_check_mark: | :x:                | :white_check_mark: |
| Halt `LitePSM`     | :white_check_mark: | :x:                | :x:                |
| Stop `Splitter`    | :x:                | :x:                | :white_check_mark: |
| Halt `SP-BEAM`     | :x:                | :x:                | :white_check_mark: |
| Wipe Line or Cap `stUSDS`| :x:                | :x:                | :white_check_mark:                  |
| Rate Setter Halt `stUSDS`| :x:                | :x:                | :white_check_mark:                  |
| Rate Setter Diss Bud `stUSDS`| :x:            | :x:            | :white_check_mark:                  |

### Wipe `line`

No further debt can be generated from an ilk whose `line` is wiped.

If `MCD_IAM_AUTO_LINE` is configured for the ilk, it will be removed.

It also prevents the debt ceiling (`line`) for the affected ilk from being changed without Governance interference.

### Set `Clip` breaker

Halts collateral auctions happening in the `MCD_CLIP_{ILK}` contract belonging to the specified ilks. Sets the breaker level to 3
to prevent both `kick()`, `redo()` and `take()`.

### Disable `DDM`

Disables a Direct Deposit Module (`DIRECT_{ID}_PLAN`), preventing further debt from being generated from it.

### Stop `OSM`

Stops the specified Oracle Security Module (`PIP_{GEM}`) instances, preventing updates in their price feeds.

### Halt `PSM`

Halts swaps on the `PSM`, with optional direction (only `GEM` buys, only `GEM` sells, both).

### Stop `Splitter`

Disables the smart burn engine.

### Halt `SP-BEAM`

Disables the SP-BEAM (Stability Parameter Bounded External Access Module) module, preventing direct rate changes by the module (rates can still be updated through the Spell process).

### Halt Rate Setter `stUSDS`

Disables the stUSDS Rate Setter module, preventing it from directly updating the stUSDS rate, by setting the Circuit breaker flag `bad` param to `1`.

### Diss Rate Setter Bud `stUSDS`

Disables `bud` _facilitator_ authorization for the stUSDS Rate Setter module on the target rate-setting endpoint, removing its permission to call privileged update functions.

### Wipe Line or Cap `stUSDS`

No further debt can be generated from stUSDS when `line` is wiped.

No further supply can be minted from stUSDS when `cap` is wiped.

## Design

### Overview

Emergency spells are meant to be as ABI-compatible with regular spells as possible, to allow Governance to reuse any
existing tools, which will not increase the cognitive burden in an emergency situation.

Previous bespoke emergency spells ([see example][example-emergency-spell]) would perform an open-heart surgery in the
standard [`DssExec`][dss-exec] contract and include the emergency actions calls in the `schedule` function. This allows
any contract using the `Mom` architecture ([see example][example-mom]) to bypass the GSM delay.

The same restrictions to regulars spells still apply (i.e.: storage variables are not allowed).

The emergency spells in this repository build on that idea with a few modifications:

1. No [`DssExecLib`][dss-exec-lib] dependency: emergency actions are quite simple by nature, which makes the use of
   `DssExecLib` superfluous.
1. No expiration time: contrary to regular spells, which are meant to be cast only once, emergency spells can be reused
   if needed, so the expiration time is set so far away in the future that in practice the spell does not expire.
1. No separate [`DssAction`][dss-action]-like contract: regular spells delegate the execution of specific actions to a
   `DssAction` contract that is deployed by the spell in its constructor. The exact reason for that design choice is
   unknown to the authors, however we can speculate that the way the spell `tag` is derived<sup>[\[1\]](#fn-1)</sup>
   requires a separate contract.
1. Casting is a no-op: while bespoke emergency spells would often conflate emergency actions with non-emergency ones,
   pre-deployed emergency spells perform only emergency actions, turning `cast()` into a no-op, which exists only for
   interface-compatibility purposes.
1. No `MCD_PAUSE` interaction: as its name might suggest, the main goal of `MCD_PAUSE` is to introduce a _pause_ (GSM
   delay) between the approval of a spell and its execution. Emergency spells by definition bypass the GSM delay, so
   there is no strong reason to `plan` them in `MCD_PAUSE` as regular spells.

[example-emergency-spell]: https://github.com/makerdao/spells-mainnet/blob/8b0e1c354a0add49f595eea01ca3a822e782ab0d/archive/2022-06-15-DssSpell/DssSpell.sol
[dss-exec]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExec.sol
[dss-exec-lib]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExecLib.sol
[dss-action]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssAction.sol
[example-mom]: https://etherscan.io/address/0x9c257e5Aaf73d964aEBc2140CA38078988fB0C10

<sub id="fn-1"><sup>\[1\]</sup> `tag` is meant to be immutable and [extract the `codehash` of the `action`
contract][spell-tag]. Notice that it would not be possible to get the `codehash` of the same contract in its
constructor.</sub>

[spell-tag]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExec.sol#L75

Some types of emergency spells may come in 3 flavors:

1. Single-ilk: applies the desired spell action to a single pre-defined ilk.
1. Grouped: applies the desired spell action to a list of related ilks (i.e.: `ETH-A`, `ETH-B` and `ETH-C`)
1. Multi: applies the desired spell action to all applicable ilks.

Furthermore, this repo provides on-chain factories for single ilk emergency spells to make it easier to deploy for new
ilks.

### About storage variables in `DssGroupedEmergencySpell`

Regular spell actions are executed through a `delegatecall` from `MCD_PAUSE_PROXY`. For that reason, they usually should
not have storage variables, as they would be accessing and interacting with `MCD_PAUSE_PROXY`'s storage, not their own.

However, Emergency Spells are not required to interact with `MCD_PAUSE` and `MCD_PAUSE_PROXY` at all. They execute
actions through regular `call` on `Mom` contracts, so we do not have this limitation.

Even if the contract is somehow misused and used as a regular spell, interacting with `MCD_PAUSE`, there would not be a
problem because the storage should not be changed outside the constructor by the concrete implementations.

### About the `done()` function

Conforming spells have a [`done`][spell-done] public storage variable which is `false` when the spell is deployed and
set to `true` when the spell is cast. This ensures a spell cannot be cast twice.

An emergency spell is not meant to be cast, but it can be scheduled multiple times. So instead of having `done` as a
storage variable, it becomes a getter function that will return:

- `false`: if the emergency spell can be scheduled in the current state, given it is lifted to the hat.
- `true`: if the desired effects of the spell can be verified or if there is anything that would prevent the spell from
  being scheduled (i.e.: bad system config).

Generally speaking, `done` should almost always return `false` for any emergency spell. If it returns `true` it means it
has just been scheduled or there is most likely something wrong with the modules touched by it. The exception is the
case where the system naturally achieves the same final state as the spell being scheduled, in which it would be also
returned `true`.

In other words, if `done() == true`, it means that the actions performed by the spell are not applicable.

[spell-done]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExec.sol#L43
