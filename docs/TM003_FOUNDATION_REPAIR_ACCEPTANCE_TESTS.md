# TM-003 Foundation Repair Acceptance Tests

**Status:** Required before a corrected foundation migration is accepted.  
**Source:** Historical foundation migration at commit `f158df5a4fcd`; review blockers documented in `docs/TM-003_GATE_1_4_MIGRATION_VALIDATION.md` at commit `875e4a9621670e632689a67351d9525c1b453a17`.

## A. Migration-chain tests

- [ ] A fresh disposable PostgreSQL/Supabase-compatible database can apply the selected migration sequence from zero.
- [ ] The selected sequence includes a committed TM-003 foundation migration before actor-hardening/runtime-guard migrations.
- [ ] The migration sequence does not execute the legacy destructive cleanup migration as part of routine deployment.
- [ ] The duplicate Revision 5 timestamp is resolved in the documented migration strategy, not by guessing an execution order.
- [ ] A repeat run or supported upgrade path is tested explicitly; idempotency must not be assumed.

## B. Authorization tests

- [ ] `tm003_has_property_access(property_id, required_role)` enforces the requested role threshold, not membership existence alone.
- [ ] An active member can read only properties and bookings within their membership scope.
- [ ] Inactive operators and inactive memberships grant no access.
- [ ] A manager in Property A cannot approve or mutate records in Property B without explicit membership/authority.
- [ ] Client-supplied actor IDs that differ from the authenticated execution actor are rejected.
- [ ] A caller cannot set arbitrary actor context from an ordinary authenticated client and gain service-level privileges.
- [ ] Anonymous and ordinary authenticated clients cannot directly insert/update/delete governed records.
- [ ] Consequential mutation functions are executable only through the intended trusted server/service-role path, with actor context independently validated.

## C. Booking lifecycle tests

- [ ] All intended valid transitions succeed.
- [ ] All invalid transitions fail without partial writes.
- [ ] A booking cannot become `GOVERNANCE_LOCKED` unless the commercial, operational and readiness preconditions are met.
- [ ] Terminal states cannot be reopened without an explicit governed exception path.
- [ ] Holds and exceptions require a valid authorized resolution path.

## D. Lock and change-control tests

- [ ] A lock snapshot matches the booking state at lock time.
- [ ] Lock versions are positive, unique per booking and advance deterministically.
- [ ] Existing locks cannot be updated or deleted by ordinary users or trusted mutation functions.
- [ ] A change request cannot be applied before approval when approval is required.
- [ ] Duplicate approval/application attempts are idempotently rejected or return the documented result.
- [ ] Patch keys are allowlisted; protected identity, authority, audit and lock fields cannot be patched.
- [ ] Native PostgreSQL types are preserved, including `timestamptz` fields such as `tentative_time`.
- [ ] The applied change creates a new lock version and records audit evidence in the same transaction.

## E. Audit and evidence tests

- [ ] Successful consequential mutations append audit records containing actor, action, booking linkage and before/after context.
- [ ] Audit records cannot be updated or deleted by ordinary clients.
- [ ] Failure/rollback leaves no partial booking, approval, lock or audit mutation.
- [ ] Signals, events and locks remain immutable after creation.
- [ ] Duplicate source signals can be linked without overwriting the original evidence.

## F. Test execution requirements

- Run the suite only against a disposable local PostgreSQL/Supabase-compatible environment.
- Record exact commit SHA, migration filenames and order, database version, command, exit status and logs.
- Do not claim a gate is green based only on a static check or a fixture that pre-creates missing schema objects.
- Keep production deployment blocked until the complete chain passes and remote schema/migration history has been separately reconciled.

## Acceptance rule

A corrected foundation is ready for review only when all mandatory tests above pass reproducibly on the exact candidate commit. A green isolated test is not authorization to apply migrations to production.
