# Architecture

_Last updated: [date] | Author: [author]_

## Overview

_Describe the system in 2–3 sentences: what it does, who uses it, and what
problem it solves._

## Components

| Component | Path | Responsibility |
|---|---|---|
| _API_ | `src/api/` | _HTTP request handling_ |
| _Domain_ | `src/domain/` | _Core business logic_ |
| _Storage_ | `src/persistence/` | _Database access layer_ |

_Edit this table to match your actual project layout._

## Data Flow

_Describe how data moves through the system. Add a diagram when helpful._

```
[Client]
   │
   ▼
[API Layer]  →  [Domain Logic]  →  [Storage]
                      │
                      ▼
               [External APIs / Services]
```

## Tech Stack

| Layer | Technology | Rationale |
|---|---|---|
| _Backend_ | _FastAPI_ | _Async, type-safe, fast startup_ |
| _Database_ | _PostgreSQL_ | _ACID, relational, battle-tested_ |
| _Infra_ | _Docker + Railway_ | _Simple containerised deploys_ |

_Replace this table with your actual stack._

## Key Design Decisions

_See [decisions/](decisions/) for the full ADR log. Link significant ones here:_

- [ADR-0001](decisions/0001-record-architecture-decisions.md) — Use ADRs to track decisions
