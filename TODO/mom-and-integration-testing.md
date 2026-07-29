# Mom and Integration Testing

## Status

This document records a deferred contract-simplification, integration-testing, and Chief Keeper plan. None of the changes described here are implemented by this document. It does not change current contracts, tests, CI, keeper behavior, deployment procedures, incident-readiness classification, or audit status.

## Decision

Future implementation should preserve `EmergencySpellV2.done()` in the compatibility ABI but define it once in the base contract as a pure function that always returns `false`. Concrete leaves, registry-global spells, and batches should remove their overrides. In particular, batches should stop aggregating leaf completion.

Emergency spells should instead be classified by the exact, case-sensitive description prefix:

```text
Emergency Spell:
```

Current V2 descriptions use strings beginning with `Emergency Spell |`. Migration must replace only those exact leading bytes with `Emergency Spell:` and preserve the remainder of every description byte-for-byte. The coordinated contract, fixture, publication, and keeper work should not make any other description rewrite. The design should not add a marker function or a uniform execution event.

This change removes a generic current-state query that cannot reliably capture future regressions, newly enrolled registry entries, or the operational evidence needed after an emergency execution. The replacement is exact action-wiring tests, direct state assertions, existing action-specific events, and explicit operational verification.

## Contract Changes

### Base compatibility behavior

`EmergencySpellV2` should provide the only implementation of:

```solidity
function done() external pure override returns (bool) {
    return false;
}
```

The function preserves the selector, zero-argument calldata shape, and `bool` return signature expected by DssExec-compatible consumers. Its Solidity JSON ABI entry changes `stateMutability` from `view` to `pure`, so normalized ABI output is not byte-for-byte identical. Generated bindings, ABI fixtures, manifest fixtures, deployment readbacks, and compatibility tests must be updated to expect that explicit mutability change. The always-false result is a compatibility value, not a completion predicate. Leaf, global, and batch contracts should not override it.

The implementation should retain the current execution-time invariants. Constructor validation, Chief/Mom authorization behavior, constrained action calls, range validation, atomic rollback, batch leaf ordering, batch delegatecall identity, and other safeguards on the execution path must not be weakened merely because completion predicates are removed.

### Remove `done()`-only dependencies

Each contract should remove interfaces, immutable values, constructor lookups, and test fixtures used exclusively by its current `done()` override. It should retain:

- inputs needed to execute the Mom call;
- subject metadata needed for execution, `description()`, or validation;
- constructor object-graph checks that bind the Mom, subject, and related contracts;
- metadata and getters still required by deployment records or operational verification.

The inventory must be confirmed contract by contract. Known removals include:

- `LineWipeSpellV2`: remove the single-target leaf's `autoLine` and `vat` immutables, the `LineMomLike.autoLine()` constructor lookup, the Chainlog `MCD_VAT` lookup, and the `AutoLineLike` and `VatLike` read interfaces used only by `done()`. Retain `lineMom` and `ilk`, which are execution inputs and description metadata.
- `StUsdsWipeParamSpellV2`: remove the `vat` and `ilk` immutables, the Chainlog `MCD_VAT` lookup, the `StUsdsLike.ilk()` lookup, and read methods or interfaces used only by `done()`. Retain `stUsdsMom`, `rateSetter`, `stUsds`, and `param`; retain the stUSDS subject validation and object-graph checks that confirm the Mom and rate setter refer to the selected stUSDS subject.

The future patch should explicitly review ABI, immutable readback, deployment verification, manifest fixtures, CLI fixtures, and constructor/object-graph test impact. Removing public immutable getters changes the ABI even though `done()` itself remains present.

### Global postconditions remain

Registry-global spells should retain their current per-entry execution-time postcondition checks. These checks detect a Mom call that returned without producing the required state for the entry being processed and make the transaction roll back. They are execution invariants, not replacements for a generic `done()` query.

This work should not add equivalent postcondition reads to single-target leaves. Leaf integration tests and operators should verify state directly after execution.

## Unit-Test Model

### Leaves and standalone spells

Each action-specific suite should prove:

- the exact Mom function selector;
- the exact subject and action arguments;
- the required authorization path and unauthorized revert;
- direct downstream state changes produced by the fake Mom;
- repeatability, including a second successful call where the production action is intended to be idempotent;
- retained constructor object-graph validation and malformed-subject checks;
- the exact `description()` value after replacing only the leading `Emergency Spell |` bytes with `Emergency Spell:` and preserving the remainder byte-for-byte.

Tests should not contain `done()` truth tables or use `done()` as a postcondition. A small base compatibility test is sufficient to prove that the inherited ABI entry exists and always returns `false`.

Description coverage should enumerate every V2 description and prove the exact migrated bytes. Keeper classifier tests should accept the exact case-sensitive `Emergency Spell:` prefix and reject close variants, including wrong case, the old `Emergency Spell |` prefix, missing colon, leading whitespace, and strings that contain but do not begin with the prefix.

Repeatability is mandatory because the keeper cannot use `done()` to suppress execution. A spell whose underlying Mom action cannot safely tolerate the expected duplicate paths must not be treated as ready under this design.

### Batches

The batch suite should prove:

- atomic rollback if any delegated leaf fails;
- execution in the supplied leaf order;
- the batch address remains the caller identity observed by each Mom during `delegatecall`;
- one indexed `LeafExecuted(index, leaf)` event after each successful leaf;
- constructor validation, leaf uniqueness, and leaf eligibility constraints;
- repeatability of the complete batch where every included action is repeatable.

The suite should not test completion aggregation, leaf `done()` calls, or batch `done()` truth tables.

### Registry-global spells

Global suites should prove:

- inclusive and capped range behavior;
- full-call and range-call rollback;
- the current action-specific events;
- per-entry execution-time postcondition failure and rollback;
- entries added after deployment through the probe or authoritative registry;
- zero, unenrolled, or otherwise documented skipped entries;
- live target resolution from the relevant registry.

Global tests should not use a completion predicate for partial progress. Direct per-entry state and emitted events are the evidence for a selected execution range.

## RPC-Backed Integration Evidence

### Boundary and dependency discovery

The integration interface should accept only:

```text
--rpc-url <ethereum-compatible-rpc>
```

It should not require contributor-supplied Mom, subject, registry, or onboarding addresses as extra command arguments. Dependencies must be discoverable from chain state through established Chainlog entries or derived from a known subject using the production object graph.

Onboarding and Emergency Spell sources should continue compiling independently:

```text
Onboarding repository                    dss-emergency-spells
own compiler and dependencies            Solidity 0.8.16 and own dependencies
           │
           │ deploys and executes the onboarding action
           ▼
       Ethereum-compatible RPC state
           ▲
           │ discovers dependencies and reads initialized contracts
           │
    Emergency Spell integration tests
```

No Solidity import graph should cross the repository boundary.

### Direct before-and-after assertions

Every RPC-backed integration test should:

1. discover and validate the production Mom, subject, authority, and related object graph;
2. read and record every relevant initial state field directly;
3. authorize the Emergency Spell through the test Chief path;
4. execute `schedule()`;
5. read and assert every documented final state field directly;
6. assert canonical Mom, protocol, wrapper, global, or `LeafExecuted` events applicable to that path;
7. repeat the action and verify the documented repeatable behavior.

An already-complete state does not cause the spell to be skipped. The spell still executes once for the current Chief hat tenure, and the test must prove that this is safe. Tests should not perturb canonical state merely to manufacture a `done() == false` precondition.

Global integration tests should assert the state of every selected registry entry after execution. Batch integration tests should assert each leaf's state directly and should not infer batch success from an aggregate query.

### Evidence binding

Each pull request using Tenderly should commit one generic evidence descriptor at the path selected deterministically from the pull-request number:

```text
deployments/1/evidence/tenderly/pr-<number>.json
```

The descriptor schema should require:

- `schemaVersion`;
- `chainId`;
- onboarding repository identity and full commit hash;
- reviewed Emergency Spell, Mom, and related artifact hashes;
- onboarding transaction hash;
- pinned block number and block hash;
- a map of every relevant deployed address to its runtime code hash;
- the object-graph and Chainlog assertions required to discover and validate the Mom, subject, authority, and related dependencies.

The descriptor is a contributor claim plus values that the trusted workflow reads back from the supplied public RPC. Committing it does not make the claims verified and does not represent audit approval.

After mainnet deployment, perform final address-specific verification of:

- deployed addresses and runtime bytecode;
- constructor arguments and retained immutable readbacks;
- Mom and subject object-graph relationships;
- Chief and downstream authority;
- integration behavior against the final deployed instances.

Keep the following evidence classes distinct:

| Evidence | What it supports | What it does not prove |
| --- | --- | --- |
| Source review | Intended implementation and constrained call surface at a reviewed revision | Tenderly compatibility or deployed identity |
| Tenderly compatibility | Behavior against the pinned simulated onboarding state and tested code | Final mainnet address, bytecode, or current authority |
| Deployment verification | Final address, bytecode, constructor, immutable, authority, and integration readbacks | Future behavior after protocol or registry changes |

No successful test or verification stage should be described as audit approval by itself.

## Contributor-Provided Tenderly State

Before mainnet onboarding, a contributor should:

1. create a static Tenderly environment from a recorded mainnet block;
2. compile the onboarding action in its owning repository;
3. deploy the pending action when it is not already present;
4. execute it through the production-equivalent Pause Proxy path using the Tenderly Admin RPC;
5. verify expected Chainlog entries, authority, protected subjects, and object graph;
6. commit the complete descriptor at `deployments/1/evidence/tenderly/pr-<number>.json`;
7. retain the environment through the review interval;
8. share only the Tenderly Public RPC;
9. delete the environment after review or after it is superseded.

This repository should not receive the Admin RPC or Tenderly account credentials.

## `/test-on-tenderly` Workflow

### Command

A contributor should request verification by commenting:

```text
/test-on-tenderly --rpc-url https://virtual.mainnet.rpc.tenderly.co/...
```

No positional addresses, test selection, or additional options should be supported. The command should always run the complete integration suite.

### Trusted parsing and preflight

Trusted default-branch code should:

- accept the command only from the pull-request author, repository collaborators, organization members, or owners;
- reject additional arguments, malformed URLs, non-HTTPS URLs, and non-Tenderly RPC hosts;
- independently resolve and pin the pull request's actual current head commit;
- derive `deployments/1/evidence/tenderly/pr-<number>.json` from the pull-request number, load the descriptor from that pinned tree, and validate it against the trusted descriptor schema;
- apply per-pull-request concurrency so a newer request cancels an older run;
- require the descriptor and RPC to report the same Ethereum mainnet chain ID;
- fetch the onboarding transaction receipt and verify its transaction hash, success, block number, and block hash against the descriptor;
- verify that the descriptor's pinned block number resolves to its pinned block hash;
- require code at the canonical Chainlog address;
- verify every address-to-runtime-code-hash entry;
- discover the required production dependencies from Chainlog or a known subject and verify every declared object-graph and Chainlog assertion;
- compute a deterministic digest of the schema-validated descriptor;
- reject an endpoint that exposes Tenderly Admin capabilities;
- log the RPC host without unnecessarily reproducing the complete URL.

Structured parsing must prevent comment text from becoming a shell command.

### No-secret execution and reporting

The integration job should:

- use job-level read-only permissions;
- check out the pinned pull-request commit with `persist-credentials: false`;
- initialize public submodules recursively;
- install the pinned or documented Foundry toolchain;
- expose no GitHub, mainnet-provider, or Tenderly-account secret to pull-request-controlled code;
- set the validated public endpoint as `ETH_RPC_URL`;
- set `INTEGRATION_BLOCK_NUMBER` to the descriptor's exact pinned block number;
- run the complete `*IntegrationTest` suite;
- preserve full Forge output as an artifact.

Fork-neutral integration tests should consume `INTEGRATION_BLOCK_NUMBER` and create the fork at that block for Tenderly evidence. Mainnet integration behavior is separate: a trusted mainnet run may either set the variable to a deliberately pinned block or omit it to select the latest block, but it must report the resolved block number and hash and must not be presented as the pinned Tenderly check.

A separate trusted reporting job should create or update the check for the pinned head and record the independently pinned pull-request head SHA alongside the descriptor path and digest. The report should also include the pull-request number, onboarding repository and full commit, reviewed artifact hashes, onboarding transaction hash and receipt block, pinned block number and hash, verified address/code-hash entries, verified object-graph and Chainlog assertions, test count, result, and retained-log link.

The result is stale if the current live pull-request head differs from the head SHA recorded by the check, the descriptor digest computed from the current live head differs from the digest recorded by the check, the pinned block hash no longer matches, or any code-hash, object-graph, or Chainlog validation changes. A successful check is verified compatibility evidence for the descriptor claims, not deployment approval, incident readiness, or audit approval.

## Ordinary CI

Ordinary pull-request CI should continue running the complete non-integration suite without `ETH_RPC_URL` or provider secrets:

```sh
forge build --sizes
forge fmt --check
forge test --no-match-contract '.*IntegrationTest' -vvv
python3 -m compileall -q cli
python3 -m unittest discover -s cli/emergency_spells -t . -v
```

Trusted branch or internal CI may run the same complete integration suite against mainnet. External contributors should use `/test-on-tenderly --rpc-url` without receiving upstream secrets. Obsolete predicate matrices and `done()` truth-table jobs should be removed rather than carried into either CI path.

## Chief Keeper Prerequisite

The always-false ABI behavior requires a coordinated change in `chief-keeper` before a V2 Emergency Spell can be treated as incident-ready or elected.

Regular spell classification and execution logic should remain unchanged. The keeper should classify an Emergency Spell only when `description()` begins with the exact, case-sensitive `Emergency Spell:` prefix. For that class it should:

- bypass the regular `done()`, `eta()`, and `cast()` flow;
- call `schedule()` directly;
- retry a failed `schedule()` transaction under the same tenure;
- automatically confirm at most one successful execution during one Chief hat tenure;
- permit the same spell address to execute again after it is reelected following an intervening hat.

### Tenure identity and single writer

The durable tenure key should be the exact canonical Chief hat transition:

```text
(chainId, chief, transitionBlockNumber, transitionBlockHash, transitionTransactionHash, transitionLogIndex, spell)
```

Including `spell` makes the selected hat explicit. The same spell address after an intervening hat has a different transition identity and is therefore a new tenure.

Exactly one keeper instance may send transactions for a given Chief. Failover instances must remain observe-only until an explicit operator handoff, and the promoted instance must use the same durable execution ledger. This plan relies on that single-writer rule and does not add a distributed lock or consensus protocol.

### Durable execution states

Each tenure has one of three durable states:

- `UNCLAIMED`: no schedule transaction has been constructed for the tenure;
- `SUBMITTED`: a signed schedule transaction and its recovery data have been persisted, whether or not broadcast is known to have succeeded;
- `CONFIRMED`: the transaction has a successful canonical receipt.

When claiming an `UNCLAIMED` tenure, the transaction-sending keeper should:

1. construct and sign the `schedule()` transaction;
2. atomically persist the tenure key, `SUBMITTED` state, raw signed transaction, transaction hash, sender nonce, and any fee/replacement metadata required by the keeper's nonce policy;
3. broadcast only after that durable write succeeds.

A crash before broadcast therefore leaves enough information to broadcast the saved raw transaction. A crash after broadcast leaves the same transaction hash for receipt recovery. On restart, the keeper must query the saved hash and either recover its receipt or rebroadcast the identical raw transaction; it must not issue a new nonce merely because the prior broadcast result is unknown.

The keeper may move a tenure to `CONFIRMED` only when the saved transaction or an explicitly recorded replacement has a successful receipt and the receipt's block hash equals the canonical block hash at that height. During the active tenure and on startup, it should recheck the canonicality of confirmed receipts. If a receipt is orphaned, the ledger returns to `SUBMITTED` and the keeper rebroadcasts the saved transaction or follows its existing nonce policy for a recorded replacement.

A failed receipt permits a replacement or retry under the same tenure according to the keeper's nonce policy. Before broadcasting a replacement, the keeper must atomically persist the replacement raw transaction, hash, nonce, and relationship to the superseded attempt while keeping the tenure in `SUBMITTED`.

If canonical transition identity, nonce ownership, transaction lineage, or receipt state cannot be reconstructed conclusively, the transaction-sending keeper must stop and require operator reconciliation. It must not guess that the tenure is unclaimed.

Under the single-writer and shared-ledger rule, automatic execution is at most once per tenure. Loss of the durable ledger, multiple active writers, or uncoordinated operators can cause one or more duplicate executions. Mandatory action and batch repeatability is the safety boundary for those failures; the ledger is an operational duplicate-suppression mechanism, not a substitute for repeatability.

The current keeper source branch schedules a spell when `done()` is false and `eta()` is zero, as shown in the pinned [Chief Keeper source](https://github.com/sky-ecosystem/chief-keeper/blob/6cbcf87a113ba56ab22575256aca099ae272f791/chief_keeper/chief_keeper.py#L387-L402). That behavior is not sufficient for the tenure-based design because an always-false V2 spell remains continuously eligible.

The contract-side always-false V2 change may be developed before the keeper rollout, but affected V2 addresses must not be classified as incident-ready or elected until the compatible keeper behavior is deployed and operationally verified.

### Keeper tests

Keeper tests should cover:

- exact-prefix classification and close-but-invalid case or prefix strings;
- regular spell behavior remaining unchanged;
- crash before broadcast after the atomic `SUBMITTED` write;
- crash after broadcast before recording a receipt;
- receipt recovery and identical-raw-transaction rebroadcast on restart;
- failed-receipt replacement under the existing nonce policy;
- restart from each durable state;
- observe-only failover and explicit handoff using the shared ledger;
- rejection of a second concurrent transaction-sending writer;
- reorganization of a previously confirmed receipt and recovery from the orphaned receipt;
- reelection of the same spell after an intervening hat;
- transaction-sending shutdown when recovery is inconclusive.

## Operational Implications

The design intentionally provides no:

- generic current-state query;
- batch completion summary;
- automatic response to a state regression;
- automatic response to new entries appearing in a global registry after an earlier execution.

Consequently:

- repeatability is mandatory for every leaf, global operation, and batch;
- an action whose target is already complete still executes once per elected tenure;
- successful leaf and batch transactions require direct operational state verification;
- global operations require verification of the selected registry range and must be rerun deliberately for later entries or regressions;
- events support traceability but do not replace direct state reads.

## Implementation Sequence

### Phase 1: Inventory and baselines

- inventory every concrete `done()` override and every dependency used only by it;
- record current ABIs, constructor signatures, immutable getters, descriptions, deployment records, and relevant fixtures;
- identify every leaf, global, and batch repeatability assumption;
- confirm current execution-time invariants and global per-entry postcondition checks.

### Phase 2: Base and concrete contract simplification

- add the pure always-false `done()` implementation to `EmergencySpellV2`;
- remove concrete leaf, global, and batch overrides, including batch aggregation;
- remove only interfaces, immutables, and lookups proved exclusive to the removed predicates;
- update normalized ABI output, generated bindings, and fixtures for the explicit `view`-to-`pure` mutability change while preserving the selector, calldata shape, and return signature;
- retain execution inputs, required metadata, stUSDS subject validation, and constructor object-graph checks;
- do not add leaf postconditions, a marker function, or a uniform execution event.

### Phase 3: Description and fixture migration

- migrate every V2 description by replacing only the exact leading `Emergency Spell |` bytes with `Emergency Spell:` and preserving the remainder byte-for-byte;
- update exact-string unit tests, ABI/readback expectations, manifests, deployment fixtures, CLI fixtures, and publication records;
- add keeper classifier tests for the exact prefix and close-but-invalid case and prefix strings;
- document the compatibility and redeployment implications for any address already deployed.

### Phase 4: Unit and integration tests

- replace predicate truth tables with exact Mom selector, argument, authorization, state, and repeatability tests;
- retain range, rollback, event, probe-registry, constructor, and object-graph coverage;
- strengthen RPC tests with direct before-and-after state reads;
- retain batch atomicity, ordering, delegated caller identity, and `LeafExecuted` coverage without completion aggregation.

### Phase 5: Keeper rollout

- implement exact-prefix classification and the direct `schedule()` path;
- implement the exact transition tuple, single transaction-sending writer, observe-only failover, shared durable ledger, and `UNCLAIMED`/`SUBMITTED`/`CONFIRMED` state machine;
- persist the signed transaction recovery record before broadcast, recover or rebroadcast the same transaction after restart, verify receipt canonicality, and stop on inconclusive recovery;
- add crash, receipt recovery, replacement, restart, failover, concurrent-writer rejection, reorg, reelection, and inconclusive-recovery tests;
- deploy and operationally verify the compatible keeper before electing or classifying affected V2 spells as incident-ready.

### Phase 6: Tenderly and deployment evidence

- retain ordinary no-secret CI and the complete `/test-on-tenderly --rpc-url` suite;
- add and schema-validate the deterministic per-PR evidence descriptor;
- bind Tenderly evidence to the onboarding revision, artifacts, transaction, pinned block, code hashes, and object graph;
- independently pin the actual pull-request head, load the descriptor from that tree, and run fork-neutral integrations with `INTEGRATION_BLOCK_NUMBER` at the exact descriptor block;
- report the independently pinned head SHA alongside the descriptor digest and every evidence identifier;
- perform final mainnet address, bytecode, constructor, immutable, authority, and integration verification;
- publish source review, compatibility, and deployment verification as distinct evidence.

## Acceptance Criteria

The deferred work is complete only when:

- `done()` preserves its selector, calldata shape, and `bool` return signature and has one pure, always-false base implementation;
- normalized ABI output, bindings, and fixtures explicitly reflect the JSON ABI `stateMutability` change from `view` to `pure`;
- no concrete leaf, global, or batch overrides `done()`;
- batch completion aggregation and predicate truth tables are removed;
- execution inputs, required metadata, constructor object-graph checks, and global per-entry postconditions remain intact;
- known LineWipe and StUsdsWipeParam `done()`-only interfaces, lookups, and immutables are removed with ABI and fixture changes accounted for;
- every V2 description replaces only the exact leading `Emergency Spell |` bytes with `Emergency Spell:` and preserves its remaining bytes;
- keeper tests accept only the exact case-sensitive prefix and reject close-but-invalid strings;
- no marker function or uniform execution event is added;
- leaf tests assert exact Mom calls, authorization, state, and repeatability;
- batch tests cover atomicity, order, delegated caller identity, and `LeafExecuted`;
- global tests cover ranges, rollback, events, probe-registry behavior, and per-entry postconditions;
- RPC tests assert direct before-and-after production state;
- ordinary CI and `/test-on-tenderly --rpc-url` run their complete intended suites without exposing secrets;
- the deterministic per-PR descriptor is schema-validated and its receipt, pinned block, code hashes, Chainlog assertions, and object graph are read back from the public RPC;
- Tenderly integrations run at the exact `INTEGRATION_BLOCK_NUMBER`, reports contain the independently pinned pull-request head SHA, descriptor digest, and all evidence identifiers, and staleness compares the live head and current descriptor digest with the recorded values;
- Tenderly and deployment evidence is bound and classified separately;
- the tenure-aware Chief Keeper uses the exact canonical transition key, one transaction-sending writer, shared ledger, durable state machine, restart/reorg recovery, and an operator stop for inconclusive reconstruction;
- the compatible Chief Keeper behavior is deployed and verified before affected V2 spells are called incident-ready or elected;
- no test result or deployment readback is represented as audit approval.

## Suggested Verification Commands

After implementing this future work:

```sh
forge build --sizes
forge fmt --check
forge test --no-match-contract '.*IntegrationTest' -vvv
ETH_RPC_URL=<mainnet-rpc> forge test --match-contract '.*IntegrationTest' -vvv
python3 -m compileall -q cli
python3 -m unittest discover -s cli/emergency_spells -t . -v
prettier --check --prose-wrap never README.md docs TODO
git diff --check
```
