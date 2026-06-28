# Playbook: Frontend / SPA

For a client-side web application — React/Vue/Svelte/Angular/Solid, with a bundler
(Vite/Webpack/Next/Nuxt/etc.). The job is to map how the UI is structured, how
state and data flow, and what each kind of user sees and does. **Framework-agnostic**:
translate "component", "route", "store", "hook", "API client" to the equivalents the
project actually uses.

## Slice axis: **user role / app area**

Identify the audiences (e.g. anonymous visitor, signed-in user, admin) and the
major app areas (auth, dashboard, settings, a primary feature surface). Slice the
per-view sections by whichever is dominant — role if the app gates heavily by role,
app-area if it's a single-role tool.

## Phase 1 inventory (before the STOP)

- **Entry & shell**: bootstrap (`main`/`index`), the root app, the router setup,
  and any global providers (auth context, query client, theme, i18n, state store).
- **Route map**: every route — path, the page/component it renders, and its access
  control (public vs auth-gated vs role-gated). Note how gating is implemented
  (route guard component, loader, middleware) — and whether it actually works.
- **Data layer**: how the app talks to the backend — the API client(s) (axios/
  fetch wrappers), base URLs/env vars, auth header injection, and whether there's a
  shared instance, response interceptors, and 401/refresh handling.
- **State management**: global stores/atoms/contexts vs server-cache (React Query/
  SWR/Apollo) vs local component state; where each kind of state lives.
- **Forms & validation**: form library + schema validation, if any.
- **Tech-debt smells**: disabled/commented-out route guards, no 401 handling,
  duplicated API clients, secrets in client code, dead pages, mock/stub pages with
  no real data wiring, inconsistent auth storage.

Present the inventory (audiences/areas, route count, diagram set) and STOP.

## `SYSTEM_FLOW.md` structure

1. **Overview** — what the app is, framework + key libraries (table), how it's run/
   built, ports, and which backend(s) it targets.
2. **Audiences & access control** — the user types, how auth state is stored and
   read, and how routes are gated (and any gaps).
3. **App shell & providers** — the provider tree and what each global provider does.
4. **Route map** — a table (path · page component · access) and a `flowchart` of the
   route tree grouped by area/role. Call out unreachable/stub routes.
5. **Data flow** — the canonical path **page → component → state/hook → API client
   → backend → cache → render**, as a `sequenceDiagram` for one representative
   feature (e.g. a list+create). Describe the API client setup and its gaps
   (no shared instance, no refresh, etc.).
6. **State-management map** — a `flowchart` showing global store vs server-cache vs
   local state, and which screens read/write which.
7. **Per-role / per-area view flowcharts** — for each audience, a `flowchart TD` of
   what they can see and do.
8. **API contract table** — the endpoints the frontend consumes (method · path ·
   which service/hook calls it · request/response shape as the FE expects it).
   This is the FE's *view* of the contract — note mismatches with the real backend
   if you can see both.
9. **Known issues / tech debt** — disabled guards, missing 401 handling, duplicated
   clients, stub pages, cache-key bugs, secrets — severity-rated, file-cited.
10. **Open questions / VERIFY list**.

## Diagrams to produce (minimum)
- 1 route-map `flowchart` (grouped by area/role).
- 1 data-flow `sequenceDiagram` (page → hook → API client → backend → cache → UI).
- 1 state-management `flowchart`.
- Per audience: 1 view-capability `flowchart TD`.

## Grounding reminders
- Read the router config for the real route list; don't infer from folder names.
- Verify each guard actually enforces (a guard component that renders children
  unconditionally is a no-op — a common, important finding).
- Trace at least one feature fully from button → API call to prove the data path;
  note pages that render but never call the API (stubs/mocks).
- Check how the auth token is stored and attached on every request.
