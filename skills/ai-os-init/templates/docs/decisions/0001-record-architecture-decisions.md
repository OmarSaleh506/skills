# ADR-0001: Record Architecture Decisions

- **Status:** Accepted
- **Date:** [date]
- **Author:** [author]

## Context

As the project grows, significant architectural choices are made — which
framework to use, how to structure data, what trade-offs to accept. Without
a record, future contributors (including yourself 6 months later) have no
way to know *why* things are the way they are, only *what* they are.

## Decision

We will record significant architectural decisions as Architecture Decision
Records (ADRs), stored in `docs/decisions/NNNN-title-with-dashes.md`.

Each file is numbered sequentially (0001, 0002, ...), has a short slug title,
and follows the template below. Decisions are never deleted — only superseded.

## Consequences

- **Good:** Future contributors understand *why*, not just *what*.
- **Good:** Prevents relitigating the same decisions repeatedly.
- **Good:** The `new-adr` skill auto-numbers and templates new ADRs instantly.
- **Trade-off:** ADRs take time to write. Keep them concise — 200 words is
  usually enough. Write them *after* the decision, not before.

---

## Template for future ADRs

```markdown
# ADR-NNNN: [Short Decision Title]

- **Status:** Draft | Proposed | Accepted | Superseded by [ADR-XXXX]
- **Date:** [YYYY-MM-DD]
- **Author:** [author or "Claude Code"]

## Context

_What situation or requirement forced this decision?_

## Decision

_What was decided. State it directly: "We will ..."_

## Consequences

- **Good:** ...
- **Trade-off:** ...
- **Risk:** ...
```

---

## How to Create a New ADR

Tell Claude: **"create a new ADR about [your decision topic]"**

The `new-adr` skill will:
1. Find the next available number
2. Slugify your title
3. Write the file to `docs/decisions/`
4. Update the index in `docs/architecture.md`
