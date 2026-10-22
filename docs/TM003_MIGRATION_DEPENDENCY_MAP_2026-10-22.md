# TM-003 Migration Dependency Map

**Review date:** 2026-10-22  
**Baseline:** `main` at `8645b69ad92bf5b3db730a600d36f9371597b7de`  
**TM-003 candidate:** `feat/tm-003-booking-command-v1` at `dcef67f65b03650a9e60ffe004b32e16f764df50`  
**Scope:** GitHub tree and migration-file inspection only. No database was contacted or changed.

## Executive finding

**The current TM-003 candidate branch does not contain the canonical booking schema migration.** Its `supabase/migrations/` directory contains only three TM-003 migrations, and the branch tree inspected contains only five tracked files total. The actor-security migration references TM-003 tables, enum types and functions that are not created by any of those three migrations.

Therefore, the candidate branch is not a self-contained, deployable database migration set based on its checked-in files. The PR description's isolated validation claim must be reproducible with the exact head commit and a documented schema fixture before it can be accepted.

## Baseline migration inventory

| File | Observed purpose | Risk / decision |
|---|---|---|
| `000_start_fresh_cleanup.sql` | Drops legacy tables, triggers, functions and types | Destructive. Never apply to production as part of routine recovery. |
| `20260817000001_fb_operations_enhancer_mvp.sql` | Creates the Revision 5 F&B schema: properties, people, roles/memberships and operational inventory/POS-related objects | Candidate baseline schema, but it needs independent validation and reconciliation with the other migration. |
| `20260817000001_fb_operations_enhancer_mvp_step1.sql` | Starts by dropping functions, triggers and application tables using `CASCADE`, then defines a different schema approach | Destructive and conflicts with the primary migration. Do not treat as a normal sequential migration. |

### Migration version collision

The two Revision 5 files share timestamp `20260817000001`. This is a migration-history ambiguity. Their schema definitions also differ: the main file uses types such as `user_role` and `stock_movement_type`, while step1 introduces types such as `authority_level` and `movement_type`. The step1 file also drops tables that the main file creates.

**Decision required:** choose and document one canonical schema history. Do not resolve this by simply renaming or executing both files.

## TM-003 candidate migration inventory

| File | Observed behavior | Dependencies / status |
|---|---|---|
| `20260903000005_tm003_governance_enforcement_v1.sql` | No-op marker; does not create governance objects | Not a foundation migration. |
| `20260908000006_tm003_actor_security_hardening_v1.sql` | Defines actor-context helper and replaces booking mutation functions; changes function execute grants | Requires pre-existing TM-003 tables, enum types and functions. |
| `20260908000007_tm003_governance_runtime_guard_v1.sql` | Defines booking snapshot helper and immutable-lock trigger | Requires `tm003_bookings` and `tm003_booking_locks`. |

The candidate branch's `supabase/migrations/` directory contains no checked-in migration that creates the core objects referenced by these files. Examples include:

- `tm003_operators`
- `tm003_properties`
- `tm003_property_memberships`
- `tm003_bookings`
- `tm003_booking_locks`
- `tm003_change_requests`
- `tm003_booking_status`
- `tm003_change_class`
- `tm003_current_operator_id()`
- `tm003_transition_booking(...)`
- `tm003_request_change(...)`
- `tm003_approve_change(...)`
- `tm003_apply_change(...)`
- `tm003_create_booking_lock(...)`

Some may have existed in an external test harness or an earlier untracked/removed file; this review does not establish that. It establishes that their creation is not present in the candidate branch's migration directory.

## Application regression risk

The candidate branch's tree has only five tracked files in the Git tree response inspected, including the three migrations and one SQL test file. In the PR diff, the following existing application files are deleted:

- `README.md`
- `app/api/notices/route.ts`
- `app/api/staff/route.ts`
- `lib/supabase.ts`
- `supabase/migrations/000_start_fresh_cleanup.sql`
- `supabase/migrations/20260817000001_fb_operations_enhancer_mvp.sql`
- `supabase/migrations/20260817000001_fb_operations_enhancer_mvp_step1.sql`

That makes PR #12 a broad replacement/deletion change, not a narrowly additive booking feature. Do not merge the whole PR.


## Historical foundation source recovered

A prior TM-003 foundation migration was found in repository history at commit `f158df5a4fcd`:

- [Historical TM-003 foundation migration](https://github.com/crowndipsaikia001-blip/fb-operations-enhancer/blob/f158df5a4fcd/supabase/migrations/20260903000004_tm003_booking_command_v1.sql)
- Blob SHA: `8da05aea7f0027b06868ef98e43b615ce721fae9`
- Commit message: `refactor: make TM-003 migration self-contained`

This is a useful source for recovering the missing schema, but it is **not yet approved for deployment**. The contemporaneous Gate 1.4 review document reports blockers in that schema:

- `tm003_has_property_access(..., required_role)` accepts a role threshold but only checks membership existence.
- Write authorization policies are incomplete.
- Audit-log write and immutability guarantees are incomplete.
- Booking lifecycle, lock creation and approval invariants are not fully enforced by deterministic database logic.
- Operator visibility is too narrow for normal scoped operational work.

The historical migration defines the expected TM-003 tables and enums, but its own review status was **NOT READY FOR PRODUCTION APPLY**. Do not simply copy it back into the active migrations folder and deploy it. Use it as a reviewed source, correct the blockers, and validate the resulting ordered chain in a disposable database.

The later PR #12 branch appears to have reduced `20260903000005_tm003_governance_enforcement_v1.sql` to a no-op marker and no longer includes `20260903000004_tm003_booking_command_v1.sql`. The runtime-guard migration itself says it does not replace the canonical booking foundation. This explains the missing dependency at the current PR head.

## Dependency map and deployment gate

| Layer | Required prerequisite | Verification |
|---|---|---|
| Canonical foundation | One selected schema history, with all TM-003 tables/types/constraints/indexes | Fresh disposable database migration run |
| Authorization | Operator identity, active membership, property scoping, role hierarchy | Positive and negative authorization tests |
| Booking lifecycle | Booking state enum and transition function | Test every allowed and forbidden transition |
| Locking | Snapshot function, lock table, immutability trigger and version constraints | Verify lock creation and rejection of update/delete |
| Change governance | Change request schema, approved patch allowlist, approval and apply functions | Wrong-property, wrong-actor, duplicate approval and invalid-patch tests |
| Audit | Audit table and mutation audit writes | Verify success and rollback/failure behavior |
| Client security | RLS, grants and service-role-only consequential mutations | Test anon, authenticated and trusted server contexts |
| Deployment | Remote schema and migration ledger reconciled | Human-reviewed deployment plan only; no blind `db push` |

## Required next work

1. Locate or reconstruct the intended TM-003 foundation schema from version-controlled history, not from assumptions.
2. Verify that the source of each referenced object is committed and included in a reproducible ordered migration sequence.
3. Resolve the duplicate Revision 5 migration timestamp and destructive cleanup strategy.
4. Re-run validation from a clean disposable PostgreSQL/Supabase-compatible database using exactly the candidate commit and documented setup steps.
5. Only then selectively port the booking system to the recovery branch and preserve the existing application.

## Safety status

No SQL has been executed. No production database has been modified. This document records source-tree findings only.
