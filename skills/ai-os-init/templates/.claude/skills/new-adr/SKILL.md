---
name: new-adr
description: >-
  Creates a new Architecture Decision Record (ADR) in docs/decisions/.
  Auto-numbers the file based on the highest existing ADR number.
  Use when asked to "create an ADR about X", "record the decision to use X",
  "document the architecture decision for X", "add to the decision log",
  "write an ADR for X", or "record why we chose X".
---

# new-adr

Creates a properly-numbered ADR file in `docs/decisions/`.

## Steps

1. **Determine the next number**
   - List all files matching `docs/decisions/[0-9]*.md`
   - Extract the leading `NNNN` from each filename
   - Take the highest number and add 1 (pad to 4 digits)
   - If no files exist yet, start at `0002` (0001 is the bootstrap ADR)

2. **Build the filename**
   - Slugify the decision title: lowercase, spaces → hyphens, remove
     punctuation
   - Filename: `docs/decisions/NNNN-<slug>.md`

3. **Write the ADR** using the template below, filled in with the decision
   context the user provided. Leave `[date]` as today's ISO date and
   `[author]` as "Claude Code" unless the user specifies otherwise.

4. **Update the architecture doc** (optional)
   - If `docs/architecture.md` has a "Key Design Decisions" section,
     append a link row. If the section doesn't exist, skip this step.

5. **Report** the file path created and the ADR's title + number.

## ADR Template

```markdown
# ADR-NNNN: [Decision Title]

- **Status:** Draft
- **Date:** [YYYY-MM-DD]
- **Author:** [author]

## Context

_What situation or requirement forced this decision?_

## Decision

_What was decided, stated directly: "We will ..."_

## Consequences

- **Good:** ...
- **Trade-off:** ...
- **Risk:** ...
```

## Rules

- **Never overwrite** an existing ADR — create a new "Supersedes ADR-XXXX" one instead.
- **Status is "Draft"** unless the user explicitly says it's accepted.
- Keep ADRs short. If context needs more than 150 words, summarise.
