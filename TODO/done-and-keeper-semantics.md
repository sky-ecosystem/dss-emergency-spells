# Emergency Spells v2: `done()` Semantics and Keeper Compatibility

## Status

This document is an open proposal for discussion with TechOps and the wider Sky community. It does not record an approved design, an implementation commitment, or confirmation of current Chief Keeper behavior. The proposal may be adopted, rejected, or deferred.

This proposal accompanies the work in draft [Emergency Spells v2 pull request #33](https://github.com/sky-ecosystem/dss-emergency-spells/pull/33). Its purpose is to collect the feedback needed to finalize the contract and keeper semantics for DSS Emergency Spells v2.

## Decision Requested

Dewiz recommends that Emergency Spells v2 preserve `done()` in the regular-spell compatibility ABI but define it once in the base contract as a function that always returns `false`:

```solidity
function done() external view override returns (bool) {
    return false;
}
```

Under this proposal, `done()` would be a compatibility value rather than a completion predicate. Concrete leaves, registry-global spells, and batches would inherit the base implementation instead of determining whether their intended protocol state currently holds.

V1 and draft V2 descriptions currently begin with the same `Emergency Spell |` prefix. If the description is used for keeper routing, a V2-specific prefix is needed so that existing V1 spells remain on the regular-spell path while V2 spells are routed through the agreed emergency flow. A visible distinction also makes the version easier to recognize when elected addresses, logs, and deployment records are reviewed.

Dewiz therefore recommends the following exact, case-sensitive V2 prefix:

```text
Emergency Spell V2 |
```

Only the leading classifier would be changed. The action-specific remainder of each description would be preserved. For example:

```text
Current:  Emergency Spell | Line Wipe: ETH-A
Proposed: Emergency Spell V2 | Line Wipe: ETH-A
```

A smaller change would be to use `Emergency Spell:` as the V2 prefix:

```text
Alternative: Emergency Spell: Line Wipe: ETH-A
```

The alternative would still provide a unique machine-readable prefix, but the version difference would be expressed only through punctuation and could be missed during manual review. TechOps feedback is requested on whether the recommended prefix or the minimal-change alternative is better suited to keeper classification.

Adoption depends on agreement about the contract semantics, confirmation of current keeper behavior, and a verified operational path for any required TechOps-owned changes.

## Rationale

For regular Sky spells, `done() == true` communicates that the spell is no longer executable. Emergency Spells have a different lifecycle: the same reviewed spell needs to remain callable and may be elected again after an intervening Chief `hat`. Returning `true` because the intended state currently holds would conflate current protocol state with whether the emergency action may be called again.

A state-derived `done()` result is also not durable operational evidence. It cannot reliably summarize:

- a later state regression
- entries added to a live registry after an earlier execution
- partial execution of a registry range
- the completion state of a batch whose leaves protect different subjects
- whether the expected transaction, events, and post-state were observed during an incident

The proposed replacement is explicit verification: transaction status, action-specific events, direct protocol-state reads, and action-specific operational checks. Registry-global execution-time postconditions remain execution invariants as they are not replaced by, and do not replace, a generic completion query.

Lower implementation complexity is an additional benefit. A single base implementation removes action-specific completion logic, completion aggregation, and dependencies that exist only to support those queries. The smaller contract surface reduces the number of assumptions that can become stale or be implemented incorrectly in an Emergency Spell. This simplification remains dependent on action repeatability and direct verification of the expected end-state.

## Compatibility Boundary

The full regular-spell interface is preserved, including the `done()` selector, zero-argument calldata shape, `bool` return type, and `view` mutability. Keeping `view` avoids a JSON ABI difference and maintains the existing compatibility surface even though no state is read by the implementation.

Removing concrete `done()` implementations may also make some public immutable getters, interfaces, constructor lookups, and fixtures unnecessary. A contract-by-contract inventory would be required before those changes were implemented. The detailed candidate inventory remains in [the existing contract inventory](./mom-and-integration-testing.md#remove-done-only-dependencies) and is not duplicated here.

The agreed V2-specific prefix would be a routing discriminator for an already elected address. The prefix would not establish that an address is reviewed, approved, incident-ready, or authorized. Existing governance, manifest, deployment-verification, and Chief election controls remain responsible for those properties.

## Confirmation Requested from TechOps

Chief Keeper source access and implementation ownership are not assumed. Confirmation of current behavior and determination of any required implementation change are requested from TechOps. Answers are needed for the following questions:

| Area | Confirmation requested |
| --- | --- |
| Classification | How does the current keeper distinguish regular spells from Emergency Spells? Is the recommended exact, case-sensitive `Emergency Spell V2 |` prefix suitable, or is the minimal-change `Emergency Spell:` alternative preferred? |
| Current execution flow | How does the keeper currently use `done()`, `eta()`, `schedule()`, and `cast()` after a new Chief `hat` is observed? |
| Emergency execution | Can the keeper route a classified Emergency Spell through the required `schedule()` flow without changing regular-spell behavior? |
| Executability | How is it established that the elected Emergency Spell is executable before a transaction is submitted? |
| Failed or uncertain transactions | What does the keeper do after a reverted, dropped, replaced, or otherwise uncertain transaction, and when will it retry? |
| Duplicate suppression | How does the keeper prevent repeated successful automatic execution while the same spell remains the current `hat`? |
| Restarts and failover | What execution state survives a keeper restart or operator handover, and how is an in-flight transaction recovered? |
| Reorganizations | How does the keeper respond when a previously successful receipt is no longer canonical? |
| Reelection | Can the same spell address execute again after an intervening `hat` and later reelection? |
| Expected end-state | How is the action-specific expected end-state verified after execution without relying on `done()`? |
| Ownership and rollout | Are keeper changes required? If so, which changes are owned by TechOps, and what deployment and verification evidence is required before affected V2 spells are incident-ready? |

At minimum, executability is expected to be checked before a transaction is submitted, and the action-specific expected end-state is expected to be verified after execution. Neither check can be replaced by the always-false `done()` value.

Compatibility properties are defined by this proposal without prescribing a keeper storage model, transaction ledger, database schema, or failover architecture. Any required Chief Keeper implementation changes would remain under TechOps ownership.

## Action Repeatability

Always-false `done()` removes completion-based suppression from the contract interface. Keeper duplicate suppression can reduce repeated automatic submissions, but it cannot be the only safety boundary for emergency actions. Restarts, reorgs, uncertain transaction state, operator intervention, or multiple transaction senders may still produce duplicate execution attempts.

Before adoption, every leaf, registry-global operation, and supported batch needs to be inventoried for repeatability. For each action, the behavior of a second call needs to be documented as one of the following:

- succeeds without an unintended additional effect
- reverts without changing state
- requires an explicit precondition or operational restriction
- is unsafe to repeat and therefore remains incompatible with this design until addressed

A batch is repeatable only if every included action and the complete ordered batch are repeatable under the documented conditions. Incident-ready classification would not be available to a spell whose action cannot safely tolerate the expected duplicate paths under the always-false design.

## Rollout and Verification Plan

Agreement on semantics gates final contract implementation. Any required keeper rollout remains a separate operational-readiness condition. Adoption would be subject to the following verification gates:

1. The agreed meaning of `done()` and the accepted Emergency Spell classifier are recorded.
2. A contract-by-contract ABI, getter, constructor-dependency, fixture, and repeatability inventory is completed.
3. Current keeper behavior and any required keeper changes are documented by TechOps.
4. Contract changes are implemented and tested without weakening authorization, atomic rollback, range validation, batch ordering, delegated caller identity, or registry-global execution-time postconditions.
5. Any required keeper changes are deployed and verified before an affected V2 address is treated as incident-ready or elected.
6. Rollout evidence is recorded for Emergency Spell classification, unchanged regular-spell behavior, executability checks, successful execution, expected end-state verification, failed-transaction retry, duplicate suppression, restart recovery, reorg recovery, and reelection of the same address after an intervening `hat`.
7. Each affected action is verified through transaction results, expected events, and direct post-state reads rather than through `done()`.

The discussion can be concluded with adoption, rejection, or deferral once the agreed contract behavior, keeper compatibility findings, any required follow-up, and the rollout verification plan have been recorded.

## Possible Outcomes

| Outcome | Consequence |
| --- | --- |
| Adopted | Always-false `done()`, the agreed classifier, contract and test updates, and any required keeper changes are implemented. Affected V2 spells are not treated as incident-ready until the rollout gates have been satisfied. |
| Rejected | State-derived `done()` semantics are retained, with the rationale for their use across leaves, registry-global spells, batches, and keeper operation recorded. |
| Deferred | The current implementation is retained. The unresolved questions, responsible party, and condition for reopening the decision are recorded. |

## Decision Record

The outcome of the public discussion will be captured in this record.

- **Decision date:** TBD
- **Participants:** TBD
- **Outcome:** TBD — adopted, rejected, or deferred
- **Agreed `done()` behavior:** TBD
- **Agreed classifier:** TBD
- **Confirmed current keeper behavior:** TBD
- **Keeper changes:** TBD
- **Contract changes:** TBD
- **Rollout verification evidence:** TBD
- **Open follow-up items:** TBD

## References

- [Draft Emergency Spells v2 PR #33](https://github.com/sky-ecosystem/dss-emergency-spells/pull/33)
- [Detailed contract and integration-testing inventory](./mom-and-integration-testing.md#remove-done-only-dependencies)
