# TM-003 Foundation Repair Specification

**Status:** Implementation contract — NOT a deployable migration.  
**Branch:** `recovery/tm003-safe-baseline-20261022`  
**Purpose:** Turn the historical TM-003 foundation into a reviewable, test-first candidate without changing the active migration chain.

## 1. Source and current blocker

Historical source: `supabase/migrations/20260903000004_tm003_booking_command_v1.sql` at commit `f158df5a4fcd`.

Do not copy it into `supabase/migrations/` unchanged. The source has a role-checking function whose `required_role` argument is ignored; it also defines select-only RLS policies, with no complete governed write path. The current recovery branch intentionally does not contain the missing foundation in the active migration directory.

## 2. Required migration-chain decision

Before making a candidate deployable, choose and document one of these paths:

1. **Fresh-install baseline:** consolidate the legacy Revision 5 schema and TM-003 into a single ordered chain for fresh disposable databases, retaining any historical migrations needed for supported upgrades.
2. **Existing-install upgrade:** preserve the established migration history and add a new forward-only migration that safely creates TM-003 objects without replaying legacy cleanup.

Do not solve the duplicate `20260817000001` timestamp by renaming one file until the supported installation states and migration history are known. `000_start_fresh_cleanup.sql` is destructive and must not be treated as routine deployment.

## 3. Authorization contract

- Resolve the acting operator from `auth.uid()`; do not trust a client-supplied operator ID.
- Deny access if no active operator maps to the authenticated user.
- Deny access if the property is inactive, the membership is inactive, or the operator is inactive.
- Enforce a documented role hierarchy in the database. Initial proposal: `staff < captain < supervisor < manager < admin`. Unknown role codes fail closed; aliases must be explicitly mapped.
- Role checks must compare the member's role against the requested minimum role. Membership existence alone is not sufficient.
- A role hierarchy authorizes only the specified operation; it does not automatically authorize cross-property access.
- Keep governed tables RLS-enabled. Default-deny direct writes from `anon` and `authenticated`; expose only narrowly scoped mutation functions after actor validation and invariant enforcement.
- Keep privileged functions on a fixed `search_path`, revoke default `PUBLIC` execute, and grant execute only to the intended database role.
- Never use a client-settable custom GUC by itself as proof of trusted service identity.

## 4. Data invariants to enforce

1. Booking status changes follow an explicit transition matrix.
2. `GOVERNANCE_LOCKED` requires all configured commercial, operational, and readiness preconditions.
3. Lock snapshots are generated from the authoritative row inside the same transaction; clients cannot submit trusted snapshots.
4. Lock version is allocated under row lock/transaction control and is unique per booking.
5. Existing lock, signal, event, and audit evidence cannot be updated/deleted through ordinary clients or mutation functions.
6. Change requests use an allowlist of mutable business fields. Identity, property, actor, authority, readiness, lock references, and audit fields are protected.
7. Approval and patch application are atomic; the patch, new lock/version, event, and audit record commit together or all roll back.
8. Timestamps such as `tentative_time` retain native PostgreSQL types and are never converted through text as an intermediate value.
9. Every consequential mutation records authenticated actor, operation, booking, and before/after context.
10. Cross-property foreign-key references are rejected where the related records must belong to the same property.

## 5. Minimum candidate deliverables

- [ ] A candidate migration kept outside `supabase/migrations/` until chain selection is resolved.
- [ ] Database functions and grants for actor resolution, role-aware access, lifecycle transitions, lock creation, approval, and patch application.
- [ ] SQL tests for both allowed and denied paths, not just happy-path fixtures.
- [ ] Fresh disposable database test from an empty schema using the exact migration order.
- [ ] Upgrade-path test for every supported existing installation state.
- [ ] A CI result tied to the exact candidate commit SHA.
- [ ] A deployment runbook with explicit preflight, backup, rollback/forward-fix, and remote schema reconciliation steps.

## 6. Release gate

This specification does not authorize production changes. The candidate remains **NOT READY FOR PRODUCTION APPLY** until the migration chain is resolved, all acceptance tests in `docs/TM003_FOUNDATION_REPAIR_ACCEPTANCE_TESTS.md` pass on the exact candidate commit, and the actual remote schema/migration history is independently verified read-only.
