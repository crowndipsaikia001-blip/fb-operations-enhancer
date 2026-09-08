# TM-003 Runtime Gate Findings — 2026-09-08

## Current result

Commit `1430f17a414ca9ba4eb7dfc08f6c3ce20cd535ab` passed:

- TM-003 CI
- Repo checks
- migration application in the isolated runtime
- TM-003 static contract checks

It failed only in the deterministic governance fixture.

## Root cause

The v6 fixture correctly clears `tm003.actor_operator_id` for the unauthenticated-lock negative case, then restores the admin actor before continuing. However, the runtime failure occurs because the fixture's `select set_config(..., false)` does not preserve the actor context across the `DO` block in the current isolated execution path. The subsequent valid lock call therefore sees no execution actor.

The failure is:

> TM-003 lock creation requires an authenticated operator

The production security migration intentionally derives governed execution identity from `tm003_execution_actor_id()`, with the transaction-local actor context available to trusted service-role execution. The governed mutation functions reject caller-controlled actor mismatches and are not executable by `anon`/`authenticated` clients.

## Required correction

The runtime fixture should set the actor context inside the same transaction scope immediately before every governed function call that requires it, rather than depending on a setting established by an earlier top-level SQL statement. The fixture remains disposable test-only SQL and does not change production semantics.

## Gate policy

Do not merge or deploy TM-003 based on the green static/CI checks alone. The runtime governance fixture must pass the full lifecycle -> governance lock -> approval -> deterministic apply -> lock v2 -> audit scenario.

Do not run `supabase db push` against the current production project until the remote migration history has been reconciled explicitly; the legacy migration chain is known to be inconsistent and includes a destructive cleanup migration.
