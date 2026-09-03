# TM-003 Foundation Reconciliation v1.0

## Decision

TM-003 will not depend on the legacy Operations Enhancer authorization helper `has_role_at_least()` or on the legacy tables `properties` / `people` being present in the remote database.

The current linked Supabase project has no application-facing `public` schema objects corresponding to the legacy application foundation, while the repository contains multiple historical schema generations. The TM-003 migration must therefore be self-contained with respect to its required booking-command foundation and must preserve a clean integration boundary with the broader `fb-operations-enhancer` platform.

## Required TM-003 foundation boundary

TM-003 requires only these platform concepts:

- property / venue scope
- authenticated operator identity
- application role / authority for access control
- immutable evidence and audit provenance

TM-003 must not import the old enum `authority_level` as its operational escalation model. TM-003 uses the dedicated `tm003_authority_level` domain: GREEN, AMBER, RED, BLACK.

## Historical schemas intentionally not resurrected

The older MVP migration creates a broad inventory/POS/operations schema and defines `has_role_at_least(target_property_id, required_role)` against `properties`, `people`, and `property_memberships`. That authorization helper is not present remotely and is therefore not a valid dependency for a production TM-003 migration.

The more recent repository schema drafts add departments, sections, rosters, checklists, inventory, recipes, POS, and other modules. Those remain platform domains, but they are not prerequisites for the first TM-003 database gate.

## Migration strategy

1. Replace the current TM-003 migration that references unavailable legacy tables/functions.
2. Introduce a minimal, explicit TM-003 foundation for property scope and operator linkage only where necessary.
3. Keep booking-command data isolated under `tm003_*` tables/types.
4. Use deterministic, explicit authorization functions rather than relying on a historical generic helper.
5. Preserve source evidence, immutable events, immutable locks, change requests, approvals, and audit state.
6. Validate the complete SQL locally before any remote application.

## Remote safety

No destructive reconciliation is authorized. No `db reset --linked`, migration repair, or production migration push is part of this reconciliation step.

## Gate

Foundation reconciliation: DESIGN RESOLVED.

Implementation remains subject to SQL validation and integration review before production apply.
