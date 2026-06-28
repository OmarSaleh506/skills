# Playbook: Backend / API

For a server application that exposes an API (HTTP/REST, GraphQL, gRPC, RPC) and
talks to data stores and async infrastructure. **Framework- and language-agnostic** —
the same structure applies to Express/Nest/Fastify (Node), FastAPI/Flask/Django
(Python), Gin/`net/http` (Go), Spring (Java), Rails (Ruby), ASP.NET, etc.

> Translate generically. Where this file says "guard", "middleware", "validation",
> "DTO/schema", read it as *whatever that framework calls the equivalent*. NestJS
> guards ↔ FastAPI dependencies ↔ Express middleware ↔ Django middleware/permissions.
> Pydantic models ↔ class-validator DTOs ↔ Go structs+validators ↔ Java beans. Never
> assume one framework's constructs exist in another; describe what the code actually
> uses.

## Slice axis: **user role / actor**

Most APIs serve several kinds of caller (e.g. admin, regular user, partner/vendor,
service-to-service, public/unauthenticated). Identify the real actors from the auth
layer (token audiences, role/scope checks, permission decorators) and slice the
per-role sections by them. Fold structurally-identical roles together and note it.

## Phase 1 inventory (what to gather before the STOP)

- **Entry point & global pipeline**: bootstrap file; global prefix; the ordered
  chain every request passes through (middleware → auth → authorization →
  validation → handler → serialization → error handling). Note the response
  envelope shape and the error/exception mapping.
- **Actors**: how identity is established (sessions, JWT, API keys), how many token
  audiences/secrets, and how roles/scopes gate endpoints.
- **Endpoint inventory**: every route — method, path, handler, required role,
  request body/query schema. Count them; group by module/resource.
- **Data model**: entities/tables/ORM models and their relations; the DB and access
  layer (ORM/query builder); migrations location.
- **Async / side effects**: queues, background workers, event emitters, schedulers/
  cron, websockets, outbound mail/push/webhooks — and which endpoints trigger them.
- **Tech-debt smells**: auth that never expires, unauthenticated mutating routes,
  missing authorization, unbounded uploads, secrets in code, N+1s, dead/duplicate
  routes, inconsistent guards.

Present the inventory (actor list, endpoint count, diagram set) and STOP.

## `SYSTEM_FLOW.md` structure

1. **Overview** — what the service is, how it's deployed/run, ports/prefix, the
   tech stack and shared libs/modules (table).
2. **Audiences & actors** — each caller type, how its identity/authorization works,
   and how roles map to permissions. Note where roles are folded together.
3. **Global request pipeline** — the ordered lifecycle of one request (middleware,
   auth, authorization, validation, handler, serialization, filters). Include the
   response envelope and the error-to-status mapping as tables.
4. **Auth & token flow** — strategies/audiences, where credentials come from, token
   issuance + refresh. Include a login `sequenceDiagram` and a token-flow
   `flowchart`. Flag insecure settings here (and in tech debt).
5. **Per-module endpoint inventory** — one subsection per resource/module with a
   table: method · path · handler · required role · request schema. Give a total
   count.
6. **Request / response contracts** — pagination/filtering conventions, the
   side-effect catalogue (which endpoint emits which event/job), and a compact
   create/update schema summary per resource.
7. **End-to-end traces** — 2–4 representative journeys as `sequenceDiagram`s
   (auth'd write that fires a side effect; a read with filtering; the auth flow).
   Cite the files at each hop.
8. **Per-role diagrams** — for each actor: one representative request
   `sequenceDiagram` **and** one capability `flowchart TD` ("what this role can
   do" across modules).
9. **Realtime / websocket** (if present) — connection lifecycle + a message
   `sequenceDiagram`; note presence tracking and cleanup bugs.
10. **Data model** — an `erDiagram` with cardinalities and key attributes, plus
    prose notes on polymorphic/denormalized/translation patterns.
11. **Background processing & side effects** — queues + consumers + triggers
    (table), templates, schedulers. Flag declared-but-unused infrastructure.
12. **Known issues / tech debt** — the do-not-carry-over list, severity-rated,
    file-cited.
13. **Open questions / VERIFY list** — everything you couldn't confirm.

End with a one-line provenance note (branch/commit + how to regenerate).

## Diagrams to produce (minimum)
- 1 login/auth `sequenceDiagram` + 1 token-flow `flowchart`.
- Per actor: 1 request `sequenceDiagram` + 1 capability `flowchart TD`.
- 2–4 end-to-end trace `sequenceDiagram`s.
- 1 `erDiagram` for the data model.
- Websocket/event `sequenceDiagram` if applicable.

Match the gold standard's sequence style: method/path/payload on the arrow,
`Authorization:` headers shown, `Note over` for background steps.

## Grounding reminders
- Read the actual route definitions — don't infer endpoints from naming. Empty
  controllers/routers that expose zero routes are common; say so.
- Confirm authorization per route (decorator/dependency/middleware), not from the
  controller name. Note routes missing the expected guard.
- For the data model, read entity/model files and migrations; don't guess relations.
