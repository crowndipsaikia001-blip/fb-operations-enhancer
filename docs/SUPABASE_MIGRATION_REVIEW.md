# Supabase Migration Review

## Canonical source

The historical branch `project-continuation-guidance-c9564` contains:

- `000_start_fresh_cleanup.sql`
- `20260817000001_fb_operations_enhancer_mvp.sql`
- `20260817000001_fb_operations_enhancer_mvp_step1.sql`
- `20260817000001_fb_operations_enhancer_mvp.backup.sql`

The main migration is Revision 5. The `.backup.sql` file is byte-identical to the main migration on that branch and should not be treated as a second executable migration.

## Findings before execution

### 1. Stock movement convention

The canonical migration documents `stock_movements.quantity` as positive for inbound and negative for outbound. Wastage authorization inserts a negative quantity. Stock balance is calculated from the sum of movements. This is internally consistent.

### 2. Audit actor attribution

`log_audit_changes()` currently writes `changed_by = NULL`. This means the audit trail does not reliably identify the authenticated person. This must be resolved before production use.

### 3. Property-aware authorization

`get_current_user_role(target_property_id)` is property-aware, but the policies for global `roles` and some `people` operations use broad property lookups. These need explicit authorization semantics rather than `LIMIT 1` selection from memberships.

### 4. System ingestion policies

The migration contains `WITH CHECK (true)` insertion policies for system-oriented tables such as stock movements and POS records. The intended ingestion path must be explicitly defined, preferably using a trusted server-side/service-role path rather than granting broad client insertion capability.

### 5. Migration artifacts

Backup and step files should not remain mixed with the canonical executable migration set unless they are deliberately named/stored outside Supabase's migration execution path.

## Decision

**Do not execute Revision 5 yet.**

The next implementation should harden the authorization and audit model, consolidate migration artifacts, then pass CI and a read-only Supabase verification before execution.
