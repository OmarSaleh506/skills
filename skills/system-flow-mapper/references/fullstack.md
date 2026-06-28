# Playbook: Full-stack / Monorepo

For a repo that contains **both** a backend and a frontend (a monorepo like Nx/
Turborepo, or a `frontend/`+`backend/` split, or a framework that spans both like
Next.js with server routes). The deliverable combines both playbooks and adds
**end-to-end traces** that cross the boundary FE → API → DB.

Read **`references/backend.md`** and **`references/frontend.md`** first — this file
is the composition layer, not a replacement.

## Slice axis: **actor, traced end-to-end**

Pick the real actors (e.g. admin via the dashboard, end-user via the app). For each,
show the journey through *both* tiers, not two disconnected halves.

## Phase 1 inventory (before the STOP)

Everything from the backend inventory **and** the frontend inventory, plus:
- **The repo layout**: apps vs shared libraries/packages, and the import aliases or
  workspace structure that ties them together.
- **The boundary**: which frontend(s) talk to which backend(s), the base URLs/env
  wiring, and how auth flows across the boundary.
- **Coverage gaps**: backend endpoints with no FE consumer, and FE calls with no
  backend route — these are high-value findings in monorepos.

A crucial honesty point: a monorepo often ships one frontend but exposes API
surfaces for clients that **don't live in the repo** (e.g. a mobile app). Say so.
Trace the in-repo frontend fully; trace external-client surfaces from the HTTP
boundary inward.

Present the combined inventory (actors, both surfaces, coverage gaps, diagram set)
and STOP.

## `SYSTEM_FLOW.md` structure

1. **Overview** — the monorepo: apps, shared libs (alias table), how each runs,
   the data store(s) and async infra. One paragraph on how the pieces fit.
2. **Audiences & actors** — unified across tiers: each actor, its frontend (if any),
   its API audience/tokens, its roles.
3. **Global request pipeline** (from backend playbook).
4. **Auth & token flow** — issued by the API, consumed by the FE; show both sides
   and any gaps (e.g. backend supports refresh, FE never calls it).
5. **Per-module endpoint inventory** (from backend playbook), with a **"consumed
   by"** column linking each endpoint to the FE page/hook that calls it, or marking
   it unconsumed.
6. **Request/response contracts** (from backend playbook).
7. **End-to-end traces** — the centerpiece: 2–4 `sequenceDiagram`s that start at a
   UI action and go **page → hook → API client → guards → controller → service →
   DB → response → cache → UI**, citing files at every hop. Include at least one
   that fires a side effect (queue/event/websocket).
8. **Per-actor diagrams** — request `sequenceDiagram` + capability `flowchart TD`
   per actor (fold FE+API capabilities together).
9. **Realtime / websocket** (if present) — full path across tiers.
10. **Data model** — one `erDiagram` for the whole system.
11. **Background processing & side effects** (from backend playbook).
12. **Frontend current-state notes** — per page: full chain, or stub/mock/missing.
    This is where you record what's actually wired vs scaffolded.
13. **Known issues / tech debt** — combined, severity-rated, file-cited.
14. **Open questions / VERIFY list**.

## Diagrams to produce (minimum)
- Backend diagram set + frontend diagram set (see those playbooks).
- 2–4 **end-to-end** `sequenceDiagram`s crossing FE→API→DB (the key addition).
- 1 system-wide `erDiagram`.

## Grounding reminders
- Actually connect the two sides: for each traced journey, cite the FE file *and*
  the backend file at each hop. Don't assert the FE calls an endpoint without
  finding the call site.
- The "consumed by" mapping requires reading both the route list and the FE service
  files — do it; the gaps it reveals are among the most useful findings.
- Be explicit about external (out-of-repo) clients rather than inventing a frontend
  for them.
