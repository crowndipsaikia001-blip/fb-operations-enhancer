# TM-003 Remote State Reconciliation

## Status

The linked Supabase project currently presents no visible application migration history in Supabase Studio, while `supabase migration list` reports three remote-only migration versions:

- `20260831033329`
- `20260831033440`
- `20260831033533`

The current repository branch does not contain files matching those versions.

Remote application inspection also found no application tables in the `public` schema and no application authorization helper `public.has_role_at_least(...)`.

## Decision

Do not apply `supabase/migrations/20260903000004_tm003_booking_command_v1.sql` as currently authored. It assumes legacy application objects (`public.properties`, `public.people`, and `has_role_at_least`) that are not present in the inspected remote schema.

Do not use migration repair or linked database reset as a workaround.

## Foundation direction

TM-003 should be built against a deliberately reconstructed application foundation rather than recreating legacy dependencies solely to satisfy the current draft migration.

The repository contains a prior foundation model centered on `properties`, `roles`, `people`, and `property_memberships`, plus broader operational modules. The existing documentation describes those as the original Operations Enhancer foundation. The foundation will be selectively reconstructed only to the degree required by the current platform architecture.

## Next implementation gate

Create and review a new foundation migration with:

1. authentication linkage to Supabase `auth.users`;
2. property identity and timezone/currency;
3. role and authority model separated from TM-003 operational escalation authority;
4. property memberships and authorization helper functions;
5. minimal audit infrastructure required by TM-003;
6. no destructive cleanup of existing Supabase-managed schemas;
7. no dependence on unavailable legacy tables beyond the intentionally reconstructed foundation.

After review, TM-003 will be revised to reference this foundation explicitly, followed by local static checks and a controlled remote dry-run/apply.
