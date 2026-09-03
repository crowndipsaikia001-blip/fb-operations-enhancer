# TM-003 Gate 1.8 Review

## Status
BLOCKED FOR MERGE / REMOTE APPLY

The complete PR diff was reviewed as a single unit. The architecture is directionally correct, but the current mutation layer still has material invariant gaps and the SQL tests do not accurately exercise the same authorization path used in production.

## Findings

1. Lock creation must be constrained to `GOVERNANCE_LOCKED` + `READY_FOR_LOCK` and must preserve a coherent lock chain.
2. The caller-controlled actor parameter is acceptable only for trusted service-role execution and must not be exposed to untrusted clients.
3. Material-change approval must reject repeated approval and cannot permit caller-supplied bypass of the approval requirement.
4. A dedicated apply-change operation is still required. Approval alone must not alter governed booking state, and proposed patches must be validated before application.
5. Test fixtures currently rely on direct table writes to create readiness, so they do not prove that the governed mutation path enforces readiness itself.
6. The SQL test transaction must not leave any test data in a persistent environment.
7. The verification contract referenced `tm003_apply_change` before the function existed; this is now tracked as a required implementation gate, not a passed check.

## Decision

Do not mark PR #12 ready for merge yet.

Next implementation gate:
- add deterministic `tm003_apply_change`;
- validate property scope and approval state during application;
- create a new lock version from the applied governed state;
- update tests so the positive and negative cases exercise the same mutation functions used by the application;
- review RLS and function privileges again after the new function is added.

No production database apply is authorized until these conditions pass.