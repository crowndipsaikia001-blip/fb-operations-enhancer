# Repository Recovery Status

**Review date:** 2026-10-22  
**Purpose:** Safely resume booking-control and F&B operations development without merging broad, unverified changes or modifying production data.

## Confirmed baseline

- Recovery branch: `recovery/tm003-safe-baseline-20261022`
- Starting commit: `8645b69ad92bf5b3db730a600d36f9371597b7de`
- Starting commit message: `Document LOOP_Automated owner briefing and Pages deployment`
- Stack: Next.js, React, TypeScript, Supabase.
- The baseline README describes the owner briefing and the existing operational data model: properties, people, roles, inventory, stock movements, transfers, purchase orders, wastage, POS tickets, audit logging and RLS.

This branch was created from the exact commit above. No existing branch was overwritten, no pull request was merged, and no Supabase database was changed.

## Pull request review

### PR #12: TM-003 Booking Command System V1

- State: open, draft, not merged.
- Head: `dcef67f65b03650a9e60ffe004b32e16f764df50`
- Reported change size: 93 files, 230 additions, 15,086 deletions.
- The feature branch is reported as 60 commits ahead and 7 behind in a comparison against the inspected baseline.
- The PR removes existing files including `README.md`, `app/api/notices/route.ts`, `app/api/staff/route.ts`, `lib/supabase.ts`, and `supabase/migrations/000_start_fresh_cleanup.sql`.
- The migration `20260903000005_tm003_governance_enforcement_v1.sql` is a no-op marker. The actor-security and runtime-guard migrations add important logic, but must be reviewed together with the complete ordered schema and migration history.
- The PR describes isolated PostgreSQL validation and passing application checks. These claims still need to be reproducible from the exact current head before acceptance.

**Decision:** Do not merge PR #12 as a whole. Review and selectively port only the required booking-control changes after dependency and test verification.

### PR #8: Supabase migration security hardening

- Open and not merged.
- Must be reconciled with the canonical schema and TM-003 migration lineage before any deployment.
- Do not assume its migration history or remote-database description remains current without fresh read-only verification.

### PR #10: TM-001 booking control prototype

- Open draft and not merged.
- Describes a smaller booking-register experiment with completeness checks, manual WhatsApp baseline capture, retrieval timing and outcome classification.
- Treat it as a separate prototype until its files and dependencies are compared with the confirmed baseline and TM-003.

### PR #9: generated continuation PR

- Open and not merged.
- Reported change size is unusually large (21,912 files). Do not merge or use as a recovery source without a focused audit.

## Safety rules

1. Treat the database as the source of truth for operational records and Git as the source of truth for code.
2. Never run `db reset --linked`, blind `db push`, or migration-history repair against production.
3. Never copy secrets or service-role keys into repository files.
4. No production schema changes until the remote schema, migration ledger, RLS, grants and data-retention impact have been reviewed.
5. Preserve the existing application and owner-briefing experience unless a deliberate, tested change replaces them.

## Next tasks

1. Reconcile the current main reference and the pull request's recorded base SHA; the GitHub responses returned different base SHAs during this review.
2. Inventory the canonical migration files on the baseline and feature branches.
3. Map TM-003 objects to their creating migrations and identify duplicate timestamps, destructive operations, missing dependencies and grant/RLS changes.
4. Run the application checks and database tests in an isolated environment from the exact candidate commit.
5. Prepare a minimal port plan and review it before changing application code or opening a merge-ready PR.

## Current state

This is a recovery record only. No application source code has been changed by this review, no pull request has been merged, and no production database operation has been performed.
