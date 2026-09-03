# TM-003 Gate 1.4 Migration Validation

## Status

IN PROGRESS

## Objective

Validate the TM-003 database migration structure before any production database write.

## Current migration under review

`supabase/migrations/20260903000004_tm003_booking_command_v1.sql`

## Validation findings

### PASS: no legacy foundation dependency in table definitions

The migration defines TM-003-scoped foundation tables and the booking domain uses `tm003_properties` rather than unavailable `public.properties`.

### PASS: dedicated operational authority enum

TM-003 uses `tm003_authority_level` with `GREEN`, `AMBER`, `RED`, and `BLACK`. This remains separate from legacy platform authorization concepts.

### PASS: provenance foundation

Signals carry `property_id`, booking linkage, source metadata, timestamps, raw content, extraction status, payload, confidence, and duplicate linkage.

### PASS: immutable evidence objects

Signals, booking events, and booking locks are protected against update/delete by database triggers.

### PASS: versioned lock structure

Booking locks enforce positive version numbers and uniqueness per booking/version. The booking's latest lock pointer is added only after the lock table exists.

### PASS: no destructive migration operations

The migration does not drop application or Supabase-managed objects.

### BLOCKER: role-aware access helper does not use `required_role`

`tm003_has_property_access(target_property_id, required_role)` accepts a role parameter but currently only tests membership existence. It therefore does not actually enforce the requested role threshold. This must be fixed before production use.

### BLOCKER: write policies are incomplete

The migration currently defines primarily SELECT policies. The application requires governed INSERT/UPDATE paths for bookings, signals, events, locks, change requests, tasks, escalations, outcomes, and audit records. Write authorization must be explicit and must distinguish governed service operations from ordinary user writes.

### BLOCKER: audit log immutability is incomplete

`tm003_audit_log` requires a deliberate write path and immutable protection. RLS alone is not sufficient to establish the audit guarantee required by the Constitution.

### BLOCKER: booking governance invariants are not database-enforced

The migration stores status, readiness and authority fields but does not yet enforce the critical lifecycle rules, lock creation/update sequence, or approval constraints. These belong in deterministic database/service logic, not AI prompts.

### BLOCKER: operator visibility is too narrow for operational execution

The current policy allows an operator to see only themselves in `tm003_operators`. TM-003 requires role-based operational views and execution ownership. A scoped operator directory policy is required.

## Gate decision

**NOT READY FOR PRODUCTION APPLY**

The current migration is structurally cleaner than the original version, but it is not yet governance-complete. Continue hardening before creating or applying a remote migration.

## Next action

Refactor the migration so that:

1. authorization role hierarchy is deterministic;
2. write policies are explicit;
3. audit writes are controlled and immutable;
4. booking lifecycle transitions are validated;
5. lock creation is governed;
6. operator visibility supports execution without exposing cross-property data;
7. the final schema remains aligned with the TM-003 Constitution.
