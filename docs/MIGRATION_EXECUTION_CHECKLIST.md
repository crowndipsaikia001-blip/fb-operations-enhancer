# Supabase Migration Execution Checklist

## Status

The canonical operations migration is **not approved for execution yet**.

## Required sequence

1. Review the canonical migration in `supabase/migrations/`.
2. Keep historical backups outside the executable migration set.
3. Run repository lint/build/secret scanning.
4. Perform read-only verification against the target Supabase project.
5. Confirm the database is in the expected pre-migration state.
6. Apply the approved migration.
7. Run post-migration checks for tables, RLS, functions, triggers, and policies.
8. Run application smoke tests.

## Safety rule

Never paste or commit real Supabase credentials. Use local environment variables or the Supabase dashboard's authenticated tooling.

## Current blockers

- Audit actor attribution needs to be verified.
- Property-aware authorization needs review, especially global `roles` and `people` operations.
- System/webhook insertion policies need to be constrained to the intended execution model.
- Duplicate/backup migration artifacts need to be removed from the executable migration set.
