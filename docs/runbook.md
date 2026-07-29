# Suggested Emergency Spells Operational Runbook

> **Status:** Discussion draft. This runbook proposes an operating model for the repository as it exists today. It does not grant authority, replace governance decisions, establish service levels, or make a deployment incident-ready by itself.

## Audience and purpose

This runbook is intended for ProSec engineers maintaining Emergency Spell deployments, engineering teams delivering modules that need standby emergency coverage, and Governance Facilitators coordinating authorization during an incident.

Its purpose is to make Emergency Spell readiness part of module delivery while keeping routine Emergency Spell deployment and publication separate from regular executive spells wherever the protocol permits. In the suggested model, engineering teams supply the module-specific implementation and configuration, while ProSec deploys, publishes, and maintains the operational artifacts.

The repository manifest remains the implementation-adjacent record of deployment and review status. This runbook explains how teams might work with that record; it does not replace the manifest rules in the [deployment records reference](../deployments/README.md).

## How to use this runbook

Use the sections that match the current task:

- engineering teams can start with [Module delivery and handoff](#module-delivery-and-handoff);
- a proposed ProSec deployment steward can use [Deployment and publication](#deployment-and-publication) and [Deployment upkeep](#deployment-upkeep);
- incident participants can use [Incident use](#incident-use) together with the applicable governance and incident-coordination procedures;
- teams reviewing an event can use [Post-incident follow-up](#post-incident-follow-up);
- teams introducing the model can use [Engineering enablement](#engineering-enablement).

The document distinguishes three kinds of guidance:

- **Repository requirement** means a constraint enforced or established by the contracts, schemas, validators, or canonical repository documentation.
- **Suggested practice** means a proposed default for coordination and execution. It can be adapted and does not establish authority.
- **Governance boundary** means a decision or protocol-state change that remains subject to the applicable governance process.

## Operating principles

- Treat emergency coverage as a module-delivery requirement rather than a follow-up catalog task.
- Keep the emergency subject, fixed parameters, controller, and authority assumptions explicit at handoff.
- Use a regular spell only when the underlying protocol state must change. Contract deployment, review, simulation, and repository publication normally do not require one.
- Prefer fully parameterized deployment entrypoints when Chainlog is not ready. Chainlog-backed entrypoints are a post-hoc convenience for known shared contracts.
- Treat `incident-ready` as a reviewed lifecycle state, not a consequence of successful deployment.
- Use the latest signed canonical manifest and live validation during an incident. A local address list or stale checkout is not sufficient.
- Preserve uncertainty. Missing evidence, unresolved authority, and incomplete migration should remain visible rather than being inferred away.

## Suggested responsibilities

These responsibilities are proposed defaults. They distinguish operational stewardship from governance authority and can be adjusted as the process matures.

| Participant | Suggested contribution |
| --- | --- |
| Engineering team | Identify the emergency subject and category; implement or adapt the spell, tests, and deployment script; provide exact addresses, parameters, registry enrollment, authority assumptions, and module timing; remain available for technical review and incident support. |
| ProSec | Review the handoff; deploy from reviewed source; draft, verify, and publish deployment records; coordinate direct-use and batch-use evidence; maintain lifecycle and migration status; reassess affected batches; support incident preparation and post-incident follow-up. |
| Governance Facilitators | Coordinate the applicable governance process, confirm the canonical publication with ProSec, support Chief authorization, and retain the selected manifest commit and incident transactions in the incident record. |
| Independent reviewers or auditors | Evaluate the implementation and the relevant direct-use, batch-use, and simulation evidence without treating deployment or factory acceptance as approval. |

ProSec stewardship does not authorize ProSec to elect a Chief `hat`, change protocol permissions, approve its own security evidence, or bypass the normal governance process.

The current V1 migration records identify ownership as `unassigned`, and the canonical deployment documentation describes publication and revocation ownership as unresolved. Until that changes, references to ProSec below mean the proposed operational steward working with Governance Facilitators through the existing manual control. This runbook does not authorize ProSec to publish, revoke, or supersede records unilaterally, and it does not change the recorded ownership state.

## Boundary with regular spells

The default should be to keep the Emergency Spell artifact outside the regular executive transaction while coordinating both deliverables in the same module-delivery effort.

| Work item | Suggested path | Reason |
| --- | --- | --- |
| Deploy a leaf or registry-global spell | ProSec deployment transaction | Deployment is permissionless and can use explicit constructor inputs. |
| Deploy or compose a batch | ProSec deployment transaction through the reviewed factory | Batch construction and publication do not change protocol configuration. |
| Draft, review, verify, publish, revoke, or supersede a manifest record | Signed repository change | These are review and lifecycle records rather than protocol state. |
| Simulate Chief execution or inspect a deployed artifact | Off-chain tooling | Simulation and inspection do not require an executive spell. |
| Elect an Emergency Spell or batch as Chief `hat` | Existing Chief governance process | Chief authorization is separate from regular-spell execution. |
| Configure a module's authority path or grant authority to a Mom | Module onboarding or another regular spell when protocol state must change | The Emergency Spell cannot independently change the authority it depends on. |
| Enroll an instance in an authoritative registry | Module onboarding or another regular spell when required by that registry | Registry-global coverage depends on normal registry maintenance. |
| Publish stable shared infrastructure in Chainlog | Regular spell when governance chooses to publish it | Chainlog is protocol state. The batch factory may qualify; individual leaves, globals, and batches normally do not. |
| Replace or reconfigure a protected protocol dependency | Regular spell when the dependency is governed | ProSec should then reassess and, where necessary, replace affected Emergency Spell deployments. |

If a subject address is unavailable before the onboarding executive runs, engineering should still deliver the reviewed source, tests, script, expected configuration, and authority assumptions. ProSec can deploy through the fully parameterized entrypoint once the address exists. The handoff or release record should expose the resulting interval without incident-ready V2 coverage and keep the applicable deployment or migration status visibly pending until the artifact reaches the required lifecycle state. This does not establish a deadline or decide whether the module is formally delivered. If a reliable address is available earlier, teams may coordinate predeployment, but this runbook does not require it.

## Module delivery and handoff

### Engage during design

The engineering team should raise the emergency subject model while the module and its authority path are still being designed. Early discussion helps determine whether the appropriate artifact is a single-target leaf, a fixed-parameter leaf, or a registry-global spell. A batch is an incident-specific or planned composition of reviewed leaves, not a substitute for identifying the underlying subjects.

The module design should make clear whether normal onboarding will:

- configure a compatible Chief-based authority path;
- enroll the subject in an authoritative registry used by a global spell;
- publish any stable dependency in Chainlog;
- create the subject at a predictable address or only during executive execution.

### Prepare the handoff

An engineering handoff to ProSec should make the following information easy to verify:

- spell category and intended emergency end-state;
- exact subject, controller, registry, and fixed-parameter values;
- artifact and reviewed source commit;
- deployment entrypoint and constructor encoding;
- expected immutable readbacks and derived dependencies;
- direct-use and, when applicable, batch-use test evidence;
- expected authority path and any onboarding action required to establish it;
- registry enrollment expectations for a registry-global spell;
- expected deployment timing relative to the module executive;
- any expected interval without incident-ready coverage and the record that will show its current state;
- known limitations, unavailable evidence, or follow-up work.

The handoff need not prescribe a separate document format. A reviewed pull request, issue, or release artifact is suitable if it preserves the information and remains linkable from the deployment record.

## Deployment and publication

The exact Foundry entrypoints are maintained in the [deployment script reference](../script/README.md), and the current command syntax is maintained in the [CLI reference](../cli/README.md). The sequence below describes the suggested operational flow without duplicating every command option.

The deployment identity, review evidence, manifest validation, lifecycle dependencies, and signed-publication rules below are repository requirements. Assigning ProSec to perform the operational steps is a suggested practice that depends on adoption of the stewardship model described above.

### Direct deployments

Under the suggested ProSec stewardship model, the direct-deployment flow would be:

1. Check out the intended signed source commit with clean build inputs and initialized submodules.
2. Confirm the handoff values and decide whether the fully parameterized or Chainlog-backed entrypoint applies. Use the fully parameterized entrypoint if any required Chainlog key is not yet published.
3. Simulate the deployment script without `--broadcast`, inspect the result, and then broadcast with the intended signer configuration.
4. Run `draft-deployment` against the successful transaction and review the generated address, block, constructor arguments, runtime codehash, subjects, parameters, and immutable readbacks.
5. Add the reviewed draft to the applicable `<chain-id>/v2.json` manifest without reordering unrelated records.
6. Complete the applicable review evidence and lifecycle state. A raw draft is intentionally not `incident-ready`.
7. Run `validate-manifest` and `verify-deployment` from build inputs matching the recorded source commit.
8. Publish the manifest change in a signed commit and retain links to the deployment and review evidence.
9. When the deployment replaces V1 coverage, update the migration overlay only after the V2 record meets the replacement rules.

### Batch deployments

1. Select only published, incident-ready, batch-eligible leaves with approved direct-use and batch-use evidence.
2. Use `preflight-batch` with the exact factory, label, and unique leaves.
3. The factory uses `CREATE`, accepts any unique leaf sequence, and permits repeated deployment of the same configuration at a different address. The batch executes the supplied sequence.
4. Pass the exact preflight configuration hash to the deployment script and broadcast through the reviewed factory.
5. Run `draft-batch`, complete the structured atomic-simulation evidence, and add the reviewed record to the manifest.
6. Run `validate-manifest`, `verify-batch`, and `inspect-batch` before treating the batch as a governance candidate.

Factory acceptance proves construction, not delegatecall safety or incident readiness. Review evidence remains part of the operational security boundary.

## Deployment upkeep

ProSec should treat upkeep as event-driven rather than assuming a fixed redeployment calendar. A review is worth considering when:

- a new module or emergency subject is introduced;
- a subject, controller, authority path, registry, or ambient dependency changes;
- a registry-global source gains a new class of entry or exhibits a malformed entry;
- a source revision, audit finding, simulation result, or incident changes the evidence supporting a record;
- a leaf or factory is revoked or superseded;
- an incident-ready batch depends on a leaf or factory whose status changes;
- V1 coverage becomes eligible for replacement or needs to be retained as an exception;
- a deployment or review record is found to be incomplete, stale, or inconsistent with live state.

A maintenance pass can use the repository's existing controls:

- `validate-manifest` for V2 schema and cross-record rules;
- `validate-migration` for V1-to-V2 status and replacement bindings;
- `verify-deployment` or `verify-batch` for deployment provenance and live readbacks;
- `inspect-batch` for the current leaf set and descriptions;
- `probe-registry` to isolate registry-global entries that cannot execute successfully at a pinned block.

The lifecycle described by the manifest is `deployed` → `reviewed` → `incident-ready`, with `revoked` and `superseded` preserving history. A status change should cite its evidence and arrive in a signed commit. If a leaf or factory is no longer suitable, ProSec should identify every incident-ready batch that depends on it and update the related statuses together, as required by the manifest validator.

The team may later choose a recurring review cadence or automated monitoring. Until then, event-driven reviews, release checkpoints, and incident exercises provide useful opportunities without implying an unapproved service level.

## Incident use

This section is a preparation aid, not an incident command policy. The applicable governance and incident-coordination processes determine who makes authorization and execution decisions. Governance Facilitators coordinate the applicable Chief process but do not receive additional authority from this runbook.

### Establish the candidate set

1. Fetch the latest canonical repository state and verify the signature of the manifest commit.
2. Record the selected commit in the incident log and confirm that the worktree and submodules are clean.
3. Run `validate-manifest` and, when legacy coverage is relevant, `validate-migration`.
4. Select only artifacts published with `operationalStatus: "incident-ready"` whose category, subject, parameters, and review evidence match the intended mitigation. Review or manifest presence alone is insufficient.
5. Re-run `verify-deployment` or `verify-batch` against the candidate address and current live state.

### Prepare execution

- For one incident-ready action, prefer the applicable leaf or registry-global spell directly.
- For several leaf actions that must share one Chief-authorized address and execute atomically, preflight and verify the exact batch.
- Inspect the proposed batch sequence and descriptions before governance handoff.
- Simulate with the proposed spell or batch as the live Chief `hat`. For a batch, inspect the downstream caller, selected leaf effects, and atomic rollback behavior.
- Record the simulation reference, chain, block, selected address, configuration, and known limitations.

### Execute and verify

Governance Facilitators should coordinate the applicable Chief process and confirm the elected address. After execution, operators should check the transaction status, canonical Mom or protocol events, affected protocol state, and the spell's `done()` result where it can be read reliably. Batch executions also emit indexed `LeafExecuted` events in the supplied sequence; batch-eligible leaves do not emit their own wrapper events.

Registry-global calls remain atomic. If a full call reverts, run `probe-registry --spell <address>` to simulate every singleton range at one pinned block. Review the reported failure reasons and safe contiguous ranges before deciding whether partial mitigation is appropriate. Execute only the reviewed ranges, account for registry changes between transactions, and rerun the probe against current state. Reverted calls do not produce canonical queryable events; successful range transactions retain their action-specific success events. After incomplete range execution, `done() == false` is expected while an actionable covered entry remains unresolved and should be reconciled with the excluded indices and post-state checks.

Record the elected address, manifest commit, simulation, execution and range transactions, post-state checks, unresolved entries, and any decision to stop or continue.

## Post-incident follow-up

After immediate response, ProSec and the participating teams should consider:

- reconciling the incident log with the published artifact and evidence;
- revoking or superseding an artifact whose assumptions no longer hold;
- reassessing batches that depend on an affected leaf or factory;
- reassessing migration status when the incident changes the basis for V1 retention, revocation, or V2 replacement;
- capturing registry entries, permission failures, tooling gaps, and manual workarounds observed during execution;
- proposing focused repository, module, or process changes;
- sharing lessons with engineering teams without turning incident-specific workarounds into default policy automatically.

## Engineering enablement

The aim of education is to make emergency coverage easier to include in module delivery, not to create a separate certification program. Useful initiatives may include:

- a short module-integration checklist based on the handoff section above;
- one worked example showing an explicit deployment before Chainlog publication and the later ProSec publication flow;
- early-design consultations or office hours for teams selecting a subject model or authority path;
- occasional tabletop exercises covering direct, batch, and registry-global incidents;
- concise briefings when spell interfaces, manifest rules, deployment scripts, or Chief assumptions change;
- a feedback path for teams to report ambiguous responsibilities or tooling friction.

The team can choose the cadence and format based on demand, architectural change, and incident experience. Participation and completion requirements are outside this suggested runbook.

## Open questions

The operating model may need further discussion before it becomes policy:

- What substantive evidence and reviewer-independence standards should support approved `reviewed` and `incident-ready` transitions?
- How should ProSec stewardship be reflected in canonical ownership records if the suggested model is adopted?
- Which lifecycle changes require a second reviewer or Governance Facilitator acknowledgement?
- Should maintenance checks use a recurring cadence, event triggers, automation, or a combination?
- Which deployment and lifecycle fields should also be published through the Sky Atlas?
- What incident-log format and retention location should be used?
- When should a module be considered delivered if its subject exists but reviewed emergency coverage is not yet incident-ready?
- Which education initiatives are most useful to module teams in practice?

These questions should remain visible until the relevant teams decide them. The absence of a settled policy should not be replaced with an assumption hidden in a deployment record or incident checklist.
