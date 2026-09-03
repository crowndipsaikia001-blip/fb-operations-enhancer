# TM-003 Gate 1.5 Governance Design

## Purpose

Define deterministic database governance boundaries before the first remote database apply.

## Booking lifecycle

Allowed baseline transitions:

- ENQUIRY -> TENTATIVE, AWAITING_INFORMATION, CANCELLED, ON_HOLD
- TENTATIVE -> AWAITING_INFORMATION, AWAITING_ADVANCE, CONFIRMED, CANCELLED, ON_HOLD, EXCEPTION
- AWAITING_INFORMATION -> TENTATIVE, CANCELLED, ON_HOLD, EXCEPTION
- AWAITING_ADVANCE -> CONFIRMED, CANCELLED, ON_HOLD, EXCEPTION
- CONFIRMED -> GOVERNANCE_LOCKED, ON_HOLD, CANCELLED, EXCEPTION
- GOVERNANCE_LOCKED -> PREPARING, EXCEPTION
- PREPARING -> READY, EXCEPTION
- READY -> LIVE, EXCEPTION
- LIVE -> CLOSING, EXCEPTION
- CLOSING -> COMPLETED, EXCEPTION
- COMPLETED -> no forward operational transition
- CANCELLED -> no forward operational transition
- ON_HOLD -> TENTATIVE, AWAITING_INFORMATION, AWAITING_ADVANCE, CONFIRMED, CANCELLED, EXCEPTION
- EXCEPTION -> ON_HOLD, TENTATIVE, AWAITING_INFORMATION, CANCELLED, CONFIRMED, GOVERNANCE_LOCKED, as approved by governance

These transitions are enforced by deterministic database functions/triggers, not LLM prompts.

## Readiness invariants

- `READY_FOR_LOCK` requires commercial, operational and required governance checks to pass.
- `LOCKED` requires a newly created immutable lock snapshot.
- `EXECUTION_READY` requires execution ownership and required pre-arrival tasks to be complete or explicitly waived by governance.
- `EXCEPTION` must be accompanied by an actionable conflict/escalation record.

## Lock invariants

- First lock version is V1.
- Each booking may have only one lock version number.
- Locks are append-only and immutable.
- `latest_lock_id` may reference only an existing lock belonging to the same booking.
- A lock can only be created for a booking in an approved lockable state.
- A later material change creates a change request/event and a new lock version; existing locks are never edited.

## Approval invariants

- Material commercial or operational variation requires approval before application unless a Layer 2 rule explicitly permits auto-acceptance.
- Approval must identify approving operator and timestamp.
- A request marked approved must have an approving operator.
- Applying a material change requires approved status and successful validation.
- Rejected/blocked/impossible requests cannot be applied.

## Authorization model

TM-003 separates:

1. platform operator role: admin, manager, supervisor, staff;
2. operational escalation authority: GREEN, AMBER, RED, BLACK.

Role hierarchy is property-scoped. Higher privilege means lower numeric rank.

## Audit requirements

Consequential operations must produce append-only audit records containing actor, action, target, timestamp and relevant before/after data or event metadata.

## Failure principle

Database enforcement must reject invalid state changes rather than relying on UI behavior or AI compliance.

## Deployment gate

No production apply until:

- migration syntax/dependency review passes;
- governance constraints are represented deterministically;
- verification SQL has expected checks;
- positive and negative fixtures are defined;
- branch diff is reviewed;
- remote apply plan is explicitly authorized.
