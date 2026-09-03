# TM-003 OPERATIONAL CONSTITUTION v1.0

## LOOP-BLR BD Booking Command System
### Booking Intelligence + Hospitality Governance + Execution Control

**Status:** Canonical / Gate 0
**Applies to:** TM-003 within LOOP-BLR Operations
**Authority:** This document is the constitutional foundation of TM-003. Lower layers, configuration, prompts, UI and automation must not contradict it.

---

## 1. PURPOSE

TM-003 exists to convert fragmented booking communication into a governed operational commitment.

It must continuously help the operation answer five questions:

1. What has actually been agreed?
2. What is currently possible?
3. What information is still missing?
4. What changed since the last committed version?
5. What must happen next, who owns it, and by when?

TM-003 is not an autonomous event manager, not a generic chatbot, and not merely a booking form.

Its purpose is to remove avoidable memory burden, communication archaeology, preventable operational surprises and unnecessary management interruption while preserving human judgement where judgement matters.

---

## 2. CONSTITUTIONAL OPERATING PRINCIPLE

> **AI interprets. Rules govern. Humans approve. Staff execute. The system remembers.**

This sentence is the primary operating boundary for the system.

### AI may

- extract information from source material
- classify signals and booking events
- identify missing information
- identify conflicts and ambiguity
- calculate or recommend where deterministic validation permits
- recommend operational actions
- identify risk
- identify relevant upsell opportunities
- draft guest-facing communication
- prepare department briefs

### AI may not independently

- confirm a booking
- approve a commercial concession
- approve a discount or complimentary item
- exceed physical capacity
- alter a locked commitment
- silently overwrite history
- create a fact that was not supplied or deterministically derived
- make a binding guest commitment
- bypass an approval boundary
- suppress a material conflict or uncertainty

AI output is advisory until accepted through the appropriate governed workflow.

---

## 3. SAFETY AND PHYSICAL REALITY FIRST

Safety and physical feasibility override commercial convenience, guest pressure, AI recommendation and operational preference.

The system must never treat a desirable commercial outcome as sufficient justification to violate:

- physical capacity
- safety requirements
- legally or operationally required controls
- known equipment limitations
- staffing constraints that make execution unsafe
- other explicitly defined hard constraints

Where the system cannot establish that an arrangement is physically and operationally possible, the state must remain unresolved or escalate. It must not assume feasibility.

---

## 4. GOVERNED OPERATIONAL TRUTH

TM-003 maintains **one governed operational truth supported by multiple evidence sources**.

The current governed booking state is the authoritative operational commitment.

Evidence remains separate and immutable.

Examples of evidence include:

- WhatsApp messages
- Telegram messages
- BD-entered information
- call notes
- emails
- manually entered operational observations
- system-generated events
- approvals
- prior booking locks

Evidence may be classified, linked and interpreted, but the original evidence must not be silently rewritten.

A current booking row is a practical projection of governed state in V1. It is not the complete historical truth.

Historical truth exists across signals, events, change requests, approvals, locks, audit records and outcomes.

---

## 5. PROVENANCE IS MANDATORY

Every externally originating operational signal must have traceable provenance.

Each signal must receive a stable `SIGNAL_ID`.

Where available, the system preserves:

- source type
- source name
- source message identifier
- source timestamp
- ingestion timestamp
- original content reference
- linked booking
- classification
- extraction status
- confidence
- duplicate relationship

The system must be able to answer:

> Where did this booking fact or change come from?

A fact without traceable provenance is not equivalent to a verified operational commitment.

---

## 6. NO INVENTED FACTS

Unknown is a valid state.

The system must prefer:

`UNKNOWN`

or

`NULL`

rather than inventing a value.

This applies especially to:

- guest count
- price
- package
- timing
- payment
- capacity
- zone
- dietary requirements
- approvals
- staffing
- menu availability
- special requests

Inference must be explicitly represented as inference and must never be silently promoted to confirmed fact.

---

## 7. HUMAN AUTHORITY

Human judgement remains the final authority for material commitments.

Human approval is required whenever a change or action crosses a defined governance boundary.

Material decisions include, at minimum:

- commercial variation
- discount outside configured authority
- complimentary outside configured authority
- material capacity exception
- significant operational exception
- package change
- payment exception
- guest commitment that exceeds established scope
- critical escalation

The system must route the decision to the correct authority rather than defaulting to a particular individual.

Authority belongs to a role and governance rule, not to an AI model.

---

## 8. HOSPITALITY PRESENCE + CONTROLLED FLEXIBILITY

TM-003 is designed to support hospitality, not replace it with rigid process.

The intended guest experience is:

> **They have thought of everything.**

The system therefore distinguishes between:

1. agreed scope
2. flexible accommodation
3. commercial variation
4. operational exception
5. impossible request

Not every deviation is a problem.

Where a request is safely and operationally manageable within authority, the system should support elegant accommodation.

Where a boundary exists, the system should communicate it clearly and respectfully.

The system must never create false reassurance merely to avoid saying no.

Diplomatic communication means clarity delivered elegantly, not deception.

---

## 9. COMMUNICATION QUALITY IS OPERATIONAL QUALITY

Guest-facing communication generated by TM-003 must be:

- warm
- prepared
- calm
- precise
- respectful
- commercially clear
- operationally confident

In V1, binding guest-facing messages remain drafts requiring human review before sending.

The system must not invent availability, approval, pricing, concessions, timing or commitments for the sake of producing a smoother message.

---

## 10. VERSIONING AND LOCKS

A booking is an evolving governed object.

Once a booking reaches a committed state, TM-003 creates a versioned booking lock.

Example:

`LOCK V1`

A later material change does not overwrite V1.

It becomes a change request or governed event and, once accepted, produces:

`LOCK V2`

Then V3, V4 and so on.

The system must always be capable of answering both:

> What was agreed at the time?

and

> What is the current commitment?

Historical locks are immutable records.

---

## 11. CHANGE MUST BE GOVERNED

A new message does not automatically become a new booking truth.

Every material change follows this conceptual sequence:

```text
NEW SIGNAL
    ↓
LINK TO BOOKING
    ↓
COMPARE WITH CURRENT GOVERNED STATE / LOCK
    ↓
CLASSIFY CHANGE
    ↓
VALIDATE
    ↓
APPROVE WHEN REQUIRED
    ↓
APPLY
    ↓
REVALIDATE
    ↓
CREATE NEW LOCK VERSION
    ↓
UPDATE HANDOVER / TASKS / BRIEFS
    ↓
COMMUNICATE APPROVED RESULT
```

Auto-acceptance is permitted only where a Layer 2 governance rule explicitly authorizes it.

Absent such authorization, the system must not silently accept a material change.

---

## 12. RULES, NOT PROMPTS, ENFORCE GOVERNANCE

Natural-language instructions to an AI model are not a substitute for deterministic governance.

Business-critical rules must exist as explicit system rules.

Examples:

- capacity
- approval authority
- status transitions
- commercial limits
- payment conditions
- change deadlines
- escalation thresholds
- lock behaviour

AI may identify that a rule may apply.

The deterministic governance engine decides whether the rule actually applies.

The system must not use unsafe dynamic execution such as arbitrary JavaScript evaluation to implement governance rules.

---

## 13. GOVERNANCE PRECEDENCE

When two rules or instructions conflict, TM-003 resolves them in this order:

1. Safety / physical impossibility
2. Operational Constitution
3. Layer 2 Booking Governance Rules
4. Layer 3A Policy Configuration
5. Layer 3B Live Operational Configuration
6. Explicitly approved booking-specific exception
7. Human escalation where ambiguity remains

No lower layer may silently override a higher layer.

---

## 14. READINESS IS MULTIDIMENSIONAL

TM-003 must not reduce readiness to a single percentage.

At minimum it distinguishes:

### Commercial Readiness

Whether the commercial commitment is sufficiently defined and authorized.

### Operational Readiness

Whether the booking can be physically and operationally delivered under current conditions.

### Execution Readiness

Whether people, briefs, tasks, dependencies and ownership are prepared for execution.

A booking can be commercially ready without being operationally ready.

A booking can be operationally ready without being execution ready.

Paid does not automatically mean ready.

---

## 15. EXECUTION OWNERSHIP

A booking must have clear execution ownership at the appropriate stage.

The designated host is an execution owner, not merely a server label.

The host owns:

- awareness of the governed booking
- guest experience continuity
- routine in-scope resolution
- coordination with departments
- escalation according to authority

The system must make the escalation boundary explicit so that staff do not need to guess when management intervention is required.

---

## 16. AUTHORITY LADDER

TM-003 uses four escalation levels.

### GREEN

Routine, in-scope execution.

Server / host resolves within established authority.

### AMBER

Supervisor review required.

Used for moderate deviation, uncertainty or operational impact.

### RED

Management decision required.

Used for material commercial or operational exceptions.

### BLACK

Critical escalation.

Used for defined critical incidents including safety concerns, serious refusal-to-pay situations, harassment, major capacity breaches or other constitutionally critical events.

Routing is role-based. Personal contact details belong in configuration, not in business logic.

---

## 17. HUMAN-CENTRIC AUTOMATION

The objective of automation is not to automate people out of hospitality.

The objective is to remove avoidable cognitive and administrative burden so people can focus on human judgement and guest experience.

TM-003 should reduce:

- WhatsApp archaeology
- memory dependency
- repeated reconstruction of bookings
- preventable management interruption
- inconsistent judgement caused by missing information
- avoidable operational surprises

It should preserve and strengthen:

- empathy
- discretion
- service recovery
- personal attention
- judgement
- accountability

---

## 18. AUDIT BY DEFAULT

Consequential system actions must be auditable.

At minimum, the system records the lifecycle of:

- creation
- extraction
- validation
- correction
- approval
- rejection
- locking
- change
- escalation
- communication
- handover
- execution
- exception resolution
- completion

Audit records must identify actor, role, timestamp, action, target, relevant previous/new values and originating event where applicable.

Audit history must not be silently rewritten.

---

## 19. DIGITAL FP PRINCIPLE

The Digital FP is an authoritative execution handover view generated from governed booking state.

It is not an independently editable competing source of truth.

If a rendered or manually maintained representation diverges from governed booking state, the system must be able to detect or flag that drift.

The Digital FP must communicate the information departments actually need to execute the booking, including:

- current committed facts
- commercial context where operationally relevant
- guest priorities
- timing
- department requirements
- host ownership
- readiness
- risks
- open tasks
- material change history

---

## 20. EXCEPTIONS ARE FIRST-CLASS OBJECTS

An exception is not an error to hide.

When a booking cannot proceed under normal rules, TM-003 records:

- what happened
- why it is exceptional
- what rule or constraint is affected
- who owns the decision
- what mitigation is proposed
- what approval is required
- what was decided
- what changed afterward

The system must make exceptions visible rather than allowing them to disappear into chat history.

---

## 21. REVENUE WITH GOVERNANCE

TM-003 may identify and recommend contextual upsell opportunities.

It must not pressure the guest or autonomously commit commercial terms.

The BD remains responsible for choosing whether an opportunity should be proposed.

The system should learn from:

- opportunity identified
- offer made
- offer accepted/rejected
- realized revenue

Commercial intelligence must remain subordinate to approved commercial authority.

---

## 22. CLIENT RISK IS CONTROL, NOT PUNISHMENT

Client history may be used to identify operational or commercial risk.

The system must not create a punitive blacklist.

Risk observations may lead to controls such as:

- earlier reconfirmation
- clearer change deadlines
- stronger advance requirements
- explicit approval
- additional pre-event verification
- designated host

Risk recommendations must remain explainable and auditable.

---

## 23. OUTCOME AND LEARNING

A completed booking is not the end of the system's responsibility.

TM-003 should capture outcomes including:

- actual pax
- actual revenue
- upsell revenue
- incidents
- complaints
- exceptions
- execution problems
- successful recoveries
- lessons

Learning must improve rules and processes through deliberate governance.

The system must not silently rewrite rules based on a single outcome.

Operational learning becomes policy only through the appropriate governance process.

---

## 24. SOURCE-OF-TRUTH BOUNDARIES

The following boundaries are mandatory:

### Evidence source
Raw signals and source records.

### Governed truth
Current approved booking state.

### Governance
Rules determining what may happen.

### Configuration
Current approved policy and live operating conditions.

### Execution view
Digital FP, tasks and department briefs derived from governed state.

### Audit
Immutable record of consequential system actions.

No component may silently assume authority belonging to another component.

---

## 25. SECURITY AND CREDENTIALS

Secrets are infrastructure configuration, not operational booking data.

API keys and credentials must never be:

- stored in booking rows
- stored in source code
- committed to GitHub
- included in guest communication
- exposed in audit logs
- pasted into conversation as part of system setup

V1 may use secure server-side configuration such as Apps Script Script Properties.

---

## 26. FAILURE BEHAVIOUR

Failure must fail visibly and safely.

If AI extraction fails:

- preserve the original signal
- record the failure
- do not fabricate extracted values
- do not advance the booking merely because the AI call failed
- route to human/manual processing where appropriate

If validation fails:

- surface the blocking issue
- do not silently bypass the validator

If a governance decision cannot be resolved:

- escalate
- preserve uncertainty
- do not manufacture certainty

The absence of an AI response is never evidence of approval.

---

## 27. NO SILENT DESTRUCTIVE ACTIONS

TM-003 must not silently:

- delete bookings
- delete evidence
- overwrite historical locks
- rewrite approval history
- erase conflicts
- alter commercial commitments without authority
- mark a booking confirmed solely because fields were extracted
- mark a booking ready solely because required fields are populated

Destructive or irreversible actions, where ever permitted, require explicit governance.

---

## 28. HUMAN FALLBACK

The system must always provide a path to continue operations when automation is unavailable.

The fallback process must preserve:

- original information
- accountability
- approval authority
- booking identity
- auditability

Automation failure must degrade into controlled manual operation, not operational paralysis.

---

## 29. PILOT DISCIPLINE

V1 is a controlled pilot.

The pilot proves the governed intelligence loop before broad automation.

The system should first be tested against representative historical and controlled live inputs.

Full WhatsApp automation, autonomous guest communication and broad autonomous decision-making are outside the initial pilot boundary.

No claim of production readiness is valid until the defined test, governance and operational gates have been passed.

---

## 30. CONSTITUTIONAL CHANGE CONTROL

This Constitution is intentionally stable.

A change to this document is a governance change, not an ordinary configuration change.

Changes require:

1. explicit proposal
2. reason for change
3. operational impact assessment
4. review by authorized management
5. version increment
6. audit record
7. controlled implementation

A lower-level configuration must never be used as a hidden method of changing constitutional behaviour.

---

# 31. CONSTITUTIONAL NON-NEGOTIABLES

The following are absolute system design constraints:

1. **Safety overrides convenience.**
2. **Governed booking state is the operational truth.**
3. **Original evidence remains immutable.**
4. **Every external signal has provenance.**
5. **Unknown remains unknown until established.**
6. **AI is advisory, not authoritative.**
7. **Deterministic rules enforce governance.**
8. **Humans approve material commitments.**
9. **Locked states are versioned, never silently overwritten.**
10. **Readiness is commercial, operational and executional.**
11. **Exceptions are recorded, not hidden.**
12. **Execution ownership is explicit.**
13. **Guest communication must be truthful, clear and hospitable.**
14. **Auditability is built in by default.**
15. **Automation reduces cognitive burden without removing human hospitality.**
16. **Failure must degrade safely to controlled manual operation.**
17. **Learning changes the system only through governed change.**
18. **No lower layer may silently override a higher layer.**

---

# 32. OPERATING LOOP

```text
OBSERVE
  ↓
CAPTURE SIGNAL
  ↓
UNDERSTAND
  ↓
EXTRACT
  ↓
VALIDATE
  ↓
GOVERN
  ↓
APPROVE
  ↓
LOCK
  ↓
HAND OVER
  ↓
EXECUTE
  ↓
OBSERVE CHANGE
  ↓
REVALIDATE
  ↓
LOCK AGAIN
  ↓
MEASURE
  ↓
LEARN
  ↓
IMPROVE
```

---

# 33. CONSTITUTIONAL NORTH STAR

The internal operation may be complex.

The guest experience should not be.

The guest should experience:

**Prepared. Personal. Calm. Well cared for.**

The operation should experience:

**Clear truth. Clear ownership. Clear authority. Clear next action.**

That is the constitutional purpose of TM-003.
