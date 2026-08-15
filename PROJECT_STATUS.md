# L➿P_BLR_by__⩜⃝☠️__777
## Project Status & Development Roadmap

**Powered by:** Tempered_monkey  
**Sponsored by:** FLYboys

Generated: 2026-08-10 11:02:59

---

## 1. Project Identity

**Project:** fb-operations-enhancer  
**Version:** 0.1.0  
**Location:** D:\fb-operations-enhancer

### Technology

- Next.js: 16.3.0
- React: 19.2.8
- TypeScript: ^5
- Prisma Client: ^7.9.1
- Prisma CLI: ^7.9.1
- Database target: PostgreSQL
- Architecture: Next.js App Router
- ORM: Prisma

---

## 2. Current Foundation

### Repository

Git detected: False

### Prisma

Schema exists: True  
Prisma installed: True  
Current validation: **FAIL**

> IMPORTANT: Database migration must NOT be performed until Prisma validation passes.

---

## 3. Files Checked

✅ package.json
✅ package-lock.json
✅ README.md
✅ AGENTS.md
✅ CLAUDE.md
✅ tsconfig.json
✅ next.config.ts
✅ eslint.config.mjs
✅ postcss.config.mjs
✅ app\page.tsx
✅ app\layout.tsx
✅ app\globals.css
✅ prisma\schema.prisma
✅ .gitignore

---

## 4. Completed / Established

- Next.js project foundation exists.
- Node.js dependencies are installed.
- Prisma Client is installed.
- Prisma CLI is available.
- Prisma schema exists at prisma/schema.prisma.


---

## 5. Remaining Work

- [ ] Fix Prisma schema validation errors before migration.
- [ ] Create .env.example documenting DATABASE_URL.
- [ ] Create/configure .env.local with the real DATABASE_URL before database connection.
- [ ] Run Prisma migration only after schema validation passes.
- [ ] Configure PostgreSQL DATABASE_URL.
- [ ] Generate Prisma Client after schema is finalized.
- [ ] Implement roster domain models and services.
- [ ] Implement weekly-off preservation.
- [ ] Implement deterministic 1ST ↔ 2ND rotation.
- [ ] Implement RL shortage proposal workflow.
- [ ] Implement BRK operational-duty workflow.
- [ ] Implement admin approval and audit trail.
- [ ] Implement roster validation and publication gate.
- [ ] Build roster-generation UI.
- [ ] Add automated tests.
- [ ] Perform security and production deployment review.


---

# 6. Locked Roster Business Logic

The roster system must preserve the following operational model:

### Assignment Types

- 1ST = First shift
- 2ND = Second shift
- RL = Royal Shift, opening to closing
- BRK = Break duty for a specific operational period
- WO = Weekly Off

### Critical distinction

WO is NOT a shift.

RL and BRK are NOT normal rotation shifts.

Only:

1ST ↔ 2ND

participates in normal weekly rotation.

---

## 7. Reporting Groups

| Assignment | Reporting Group |
|---|---|
| 1ST | FIRST_SHIFT |
| 2ND | SECOND_SHIFT |
| RL | FIRST_SHIFT |
| BRK | FIRST_SHIFT |
| WO | NONE |

RL and BRK therefore report with the First Shift reporting group.

Actual reporting times must come from configuration, not be hard-coded into the assignment code.

---

# 8. Weekly Off Rules

Weekly Off must remain consistent for each employee unless an authorized administrator manually changes it.

A generator must NOT rotate WO as though it were a shift.

Any authorized change must be auditable.

---

# 9. Normal Rotation

The normal rotation operates only between:

1ST ↔ 2ND

RL, BRK and WO are excluded from the normal rotation state.

The system maintains the employee's normal rotation state independently from the actual assignment.

This prevents an RL or BRK assignment from corrupting the normal weekly rotation sequence.

---

# 10. Royal Shift Rules

RL may be allocated when the roster cannot satisfy minimum staffing requirements through normal staffing logic.

RL eligibility:

- Any role except GM and OM.
- Candidate must satisfy the applicable roster-group rules.
- Maximum RL allocation: **once per person per week**.
- RL is opening-to-closing.
- RL reports with the First Shift reporting group.
- RL counts toward both First Shift and Second Shift minimum coverage.

Coverage:

FIRST_SHIFT = 1ST + RL

SECOND_SHIFT = 2ND + RL

RL does NOT become two assignments. It remains one RL assignment.

---

# 11. RL Approval

The generator may identify eligible RL candidates and create proposals.

The generator must NOT silently assign or move RL.

Administrative approval is required before an RL proposal becomes an active roster assignment.

---

# 12. Break Duty Rules

BRK:

- Is demand-based.
- May be updated during operation.
- May apply to any eligible role.
- Is assigned for a specific duty period.
- Does NOT participate in 1ST/2ND rotation.
- May be assigned to someone whose normal rotation would otherwise be 1ST or 2ND.
- Requires appropriate validation.
- Changes require authorized approval.

---

# 13. Publication Gate

Before the roster is published:

1. Validate staffing coverage.
2. Validate weekly offs.
3. Validate 1ST/2ND rotation.
4. Validate RL eligibility.
5. Validate RL weekly limit.
6. Validate BRK conflicts.
7. Validate overlapping duties.
8. Validate reporting groups.
9. Recalculate final coverage.
10. Require administrative approval for pending RL/BRK changes.

No production roster should be published with unresolved critical validation errors.

---

# 14. Current Development Principle

**Do not migrate or create production database tables until:**

1. Prisma schema is valid.
2. Schema design is reviewed.
3. DATABASE_URL is configured.
4. Prisma Client generation succeeds.
5. Migration plan is reviewed.

---

## Brand

**L➿P_BLR_by__⩜⃝☠️__777**

**Powered by Tempered_monkey**

**Sponsored by FLYboys**

---

Generated automatically from the current repository state.
