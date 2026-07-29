# Emergency Spell V2 Architecture Alternatives

## Status

This document frames an open architecture discussion. It does not record an approved decision, mandatory follow-up, roadmap commitment, implementation priority, deployment prerequisite, or audit requirement. The alternatives, assessment, and reconsideration conditions still require explicit engineering and operational agreement before they can guide implementation.

Within this document, normative language describes the consequences of adopting a candidate model. It does not require that model to be adopted.

## Current Proposal for Discussion

The current proposal is to retain three distinct deployment and execution models:

- predeployed, reviewed single-target leaves for explicitly selected subjects;
- separate `Global*` spells that resolve changing target sets through authoritative registries;
- on-demand batches that compose reviewed, storage-free leaves and execute them atomically through `delegatecall`.

A reviewer proposed returning to V1-style grouped spells or action-specific factories that deploy complete grouped spells without predeployed leaves. Both models create incident-specific artifacts when composition is deferred until an incident. The distinction is what the new artifact binds: a V2 batch binds the address, leaf order, and configuration while reusing reviewed constrained leaf bytecode; an incident-time grouped generator binds action logic and dynamic targets into a new grouped artifact. Predeployed grouped spells avoid incident-time deployment but restore a catalog of fixed action groupings or fixed target lists.

## Comparison Criteria

The alternatives should be evaluated against the operational and security properties below.

| Criterion | Selected V2 model | V1-style grouped spells or action-specific factories |
| --- | --- | --- |
| Incident readiness | Reviewed leaves and registry-global spells can be deployed and verified before an incident. A direct leaf or global is ready for selection, but an on-demand batch still creates a new address, order, and configuration that require incident-time preflight, deployment verification, and publication. The action logic comes from reviewed constrained leaf bytecode. | An incident-time factory can produce a fresh grouped spell, but the exact artifact, action combination, and target list require incident-time preflight, deployment verification, and publication. Predeploying fixed groups moves that work earlier but creates a catalog that must be maintained and rechecked. |
| Target freshness | Single-target leaves intentionally pin a reviewed subject. `Global*` spells use authoritative registries when the target set must remain live. A batch can combine the already reviewed single-target actions needed for the incident. | An incident-time factory can accept a fresh target list, but freshness comes from operator-supplied deployment inputs unless an authoritative registry defines the set. A predeployed grouped spell instead freezes its list and becomes stale as subjects change. |
| Chief authorization | Chief authorizes one elected address. A direct leaf or registry-global spell can be elected directly. An on-demand batch creates a new electable address, and delegated leaf calls preserve that batch identity for authorized Moms. | A fixed or generated grouped spell is likewise one electable address. Each generated group creates a new address to verify, publish, and elect. A factory cannot make multiple independently calling addresses share the single Chief authorization boundary without putting their calls behind the grouped artifact. |
| Atomic composition | The batch executes a reviewed leaf sequence in one transaction and rolls the whole sequence back if any leaf fails. Each new batch configuration and order still requires review, but composition reuses constrained leaf implementations instead of generating new grouped action logic. | Atomicity is possible by encoding the complete action set into a grouped spell. Predeployed groups limit operators to a fixed catalog; incident-time generators support new combinations but bind the selected action logic and dynamic targets into a newly generated grouped artifact. |
| `delegatecall` storage safety | Batch-eligible leaves must keep execution inputs in bytecode-backed constants or immutables and must not depend on normal storage. That constraint makes reviewed leaves reusable under the batch's storage context. | A grouped spell can use its own storage when called directly, but it does not provide reusable leaves. If its factory stores dynamic targets or calldata, those instances cannot safely become batch leaves because delegated execution would read the batch's storage. |
| Deployment and audit burden | Each action-specific leaf is reviewed once for its supported parameters and storage-free execution path. Every batch still requires review of leaf eligibility, order, uniqueness, atomicity, configuration, and the deployed address. Registry-global spells remain separately reviewed because their live-set iteration has different failure modes. | Every fixed grouping or factory-generated shape expands the review surface. Reviewers either assess a growing catalog of fixed groups or assess a generator and then verify outputs that combine action logic and target selection. |
| Publication | Predeployed leaves and globals can have stable addresses, bytecode, constructor readbacks, authority evidence, and deployment records before use. An on-demand batch still needs incident-time publication of its address, code identity, leaf order, label/configuration, and verification evidence. | A predeployed fixed group needs the same stable publication evidence but enlarges the public catalog. An incident-time generated group needs publication of its new address, code identity, complete action logic, target configuration, and verification evidence. |

## Current Assessment

If atomic batch composition remains a requirement, the current assessment favors retaining the selected V2 model. Both an on-demand V2 batch and an incident-time grouped spell require preflight, verification, and publication of a new electable artifact. V2 keeps that new artifact limited to composition metadata and batch execution over storage-free reviewed leaves. Grouped spells do not preserve that reusable review boundary: predeployed groups restore a fixed-list catalog, while incident-time generators also bind action logic and dynamic targets into the new artifact.

This assessment does not make every single-target leaf permanently current. If the model is adopted, explicit targets would still require operational review, and changing target populations would use a separately reviewed `Global*` spell only when an authoritative registry provides the relevant set and the global execution semantics are acceptable.

## Factors That Could Change the Assessment

Revisit the current assessment if any of the following changes:

- batching is removed as a requirement;
- Chief authorization changes so multiple caller addresses can be authorized for one emergency action or multiple elected addresses can act together;
- authoritative registries cover the relevant target sets well enough that incident-time fixed target selection is no longer needed.

Any future decision should compare the new authority and registry model against the same incident-readiness, freshness, audit, deployment, and publication criteria. This discussion does not provide prior approval for either alternative.
