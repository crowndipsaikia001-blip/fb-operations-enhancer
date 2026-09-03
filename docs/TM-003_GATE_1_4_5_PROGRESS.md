# TM-003 Gate 1.4.5 Progress

## Current state

Repository-side review continues on `feat/tm-003-booking-command-v1`.

### Verified
- TM-003 schema is isolated from legacy application tables.
- Dedicated role hierarchy exists: admin < manager < supervisor < staff.
- Property-scoped access helper evaluates the requested role.
- Direct authenticated client writes are denied by default.
- Signals, booking events, and booking locks have immutable database triggers.
- Verification SQL exists at `supabase/verification_tm003_v1.sql`.
- No production database write has been performed.

## Remaining gates

1. Enforce the booking lifecycle as deterministic allowed transitions.
2. Prevent creation of an invalid lock version and require lock snapshots to correspond to governed state.
3. Separate request creation from approval and application of material changes.
4. Add server-side mutation functions that are the only supported write path for governed operations.
5. Add positive and negative SQL fixtures covering authorization, lifecycle, lock, approval, and immutability boundaries.
6. Re-review the migration and verification script as a complete unit before opening the PR.

## Deployment rule

No remote apply is authorized until all remaining gates pass and the branch is reviewed as a complete unit.
