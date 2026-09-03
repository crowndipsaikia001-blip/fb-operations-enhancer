# TM-003 Gate 1.4 Validation Report

## Status
IN PROGRESS. No production database apply authorized.

## Verified
- TM-003 schema is isolated under `tm003_*` objects and does not require legacy `public.properties`, `public.people`, or `has_role_at_least()`.
- Property-scoped authorization functions now include an explicit role hierarchy.
- RLS is enabled on all TM-003 tables.
- Immutable triggers exist for signals, booking events, and booking locks.
- Direct authenticated-client write policies are denied by default; governed writes are reserved for the server-side application path.
- Verification SQL exists at `supabase/verification_tm003_v1.sql`.

## Remaining hardening before remote apply
1. Enforce booking lifecycle transitions in deterministic database functions/triggers.
2. Enforce lock-version sequencing and lock creation prerequisites.
3. Enforce material-change approval requirements before application of proposed patches.
4. Add server-side mutation functions so business rules do not rely on service-role direct table writes.
5. Add SQL test fixtures for positive and negative governance cases.
6. Run static repository validation and review the full branch diff.

## Safety boundary
Do not apply `20260903000004_tm003_booking_command_v1.sql` to the linked production project until the above checks pass.
