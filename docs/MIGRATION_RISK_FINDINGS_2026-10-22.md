# Migration Risk Findings

**Review date:** 2026-10-22  
**Baseline inspected:** `8645b69ad92bf5b3db730a600d36f9371597b7de`  
**Status:** Read-only review. No database commands executed.

## High-priority findings

### 1. Two competing migrations share the same version timestamp

Both files exist on the inspected baseline:

- `supabase/migrations/20260817000001_fb_operations_enhancer_mvp.sql`
- `supabase/migrations/20260817000001_fb_operations_enhancer_mvp_step1.sql`

They define different schema approaches and should not be treated as a simple ordered pair. The step1 file begins by dropping functions, triggers and application tables with `CASCADE`, then creates different enum and table definitions. This is potentially destructive and not safe to run against any database containing data without a deliberate, reviewed rebuild plan.

### 2. A separate cleanup migration is explicitly destructive

`supabase/migrations/000_start_fresh_cleanup.sql` disables RLS on legacy tables and drops tables and types, including `people`, `properties`, and `roles`, using `CASCADE`.

**Rule:** Do not run this migration against production. Do not infer that an empty or partially initialized database is safe to reset without checking the actual remote state and data-retention requirements.

### 3. The type inventory does not match either migration cleanly

The checked-in `supabase-inventory/database.types.ts` describes fields such as `people.contact`, `people.property_id`, `people.role_id`, and `reservations`. The primary MVP migration defines a different people/membership structure and additional inventory entities. This generated inventory must be regenerated from a confirmed canonical schema, not used as evidence that the live database matches either migration.

### 4. TM-003 migration dependencies require a canonical foundation

TM-003 actor-security and runtime-guard migrations reference objects such as `tm003_operators`, `tm003_bookings`, `tm003_booking_locks`, `tm003_booking_status`, `tm003_change_requests`, and several mutation functions. The two TM-003 migrations alone do not establish the full foundation. Their dependency graph and the actual migration files that create each object must be confirmed before execution.

### 5. PR base references are inconsistent across repository responses

The current comparison identified baseline commit `8645b69ad92bf5b3db730a600d36f9371597b7de`, while PR #12 metadata reported a different base SHA, `875e4a9621670e632689a67351d9525c1b453a17`. The safe recovery branch was therefore anchored to the exact inspected commit SHA. Reconcile the refs before deciding which later commits should be included.

## Required next actions

1. List all migration filenames from the baseline and TM-003 branch, sorted by version.
2. Build a dependency table: object/function, creation migration, later modifications, grants, RLS policies, tests.
3. Choose one canonical base schema. Explicitly mark conflicting or destructive migrations as archived/manual-only until resolved.
4. Run migrations and SQL tests against a disposable local PostgreSQL/Supabase-compatible instance, starting from an empty database and separately testing upgrade paths where applicable.
5. Inspect the remote project read-only and compare schema and migration history. Do not apply, repair history, or reset production as part of this audit.
6. Port the smallest complete TM-003 slice onto the recovery branch only after the above checks pass.

## Current safety status

- Recovery branch created from the inspected baseline.
- Recovery notes committed to the recovery branch.
- No application code changed.
- No pull request merged.
- No production database changes or migrations executed.
