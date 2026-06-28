---
name: system-flow-mapper
description: >-
  Produces three grounded deliverables for ANY codebase by reading it (source
  unchanged), written into the project under docs/system-flow/:
  SYSTEM_FLOW.md (deep technical reference),
  system-flow.html (jargon-free offline companion for non-technical readers), and
  system-flow-technical.html (interactive offline reference for engineers: searchable
  endpoint cards, actor
  sidebar, sequence diagrams, light/dark toggle). Detects
  project type first and routes to the right playbook (backend/API, frontend/SPA,
  full-stack/monorepo, Pulumi, Flux/GitOps, or generic IaC). Use this whenever the
  user wants to "map the flow", "understand how this project works", "document the
  system", "draw the request/response flow", "diagram the architecture", "trace how
  data moves", "explain the request lifecycle", "show what each user/role can do",
  or "onboard me to this codebase" — across frontend, backend, full-stack, or
  infrastructure-as-code repositories, even if they don't name these files
  explicitly. Prefer this skill over ad-hoc exploration whenever the goal is a
  durable architecture/flow document plus a plain-language companion.
---

# System Flow Mapper

Reproduce, on any project, a three-part deliverable:

1. **`$DOCS_DIR/SYSTEM_FLOW.md`** — the source-of-truth
   technical map (how data moves, what each actor can do, the data model, async paths,
   and a tech-debt list).
2. **`$DOCS_DIR/system-flow.html`** — a self-contained,
   fully-offline, jargon-free visual companion for non-technical readers.
3. **`$DOCS_DIR/system-flow-technical.html`** — a
   self-contained, fully-offline, interactive technical reference: searchable endpoint
   cards with method badges and role chips, actor-scoped sidebar navigation, sequence
   diagrams, and a light/dark toggle. For engineers and reviewers.

`$DOCS_DIR` is `docs/system-flow/` inside the analyzed project (computed in Step 0c).

This is a **read-only analysis of the project's source** — never change
application, config, or source files. The only files you create are this skill's
own deliverables under `$DOCS_DIR/` (the three docs, per-section fragments, and
`state.json`). The one project file you may touch is `.gitignore`, and only with
the user's say-so (see Step 0c).

The bar: deep, **grounded** (every claim cites a real `path:line`), and honest
(anything you can't confirm is tagged `VERIFY`, never guessed). The companion HTML
must read like a friendly explainer with zero jargon.

---

## Data sources: files by default; live infra reads only on opt-in

**Default — and ALWAYS in non-interactive / benchmark / automated runs:** work
**strictly from committed files, read-only.** Derive everything from what's in the
repo. Do **not** invoke project CLIs (`pulumi`, `flux`, `kubectl`, etc.), and do not
contact any live cluster, cloud account, or state backend. Any live-only state that
can't be read from files is tagged **`VERIFY`** rather than guessed.

**Optional live-read mode (infra projects only, opt-in per run):** if — and only
if — the user explicitly opts in for this run (e.g. *"run in live mode"* / *"you can
use the cluster"*), the Pulumi/Flux/IaC playbooks may run **read-only** introspection
commands to fill in live state. The infra playbooks **offer** this during Phase 1 and
list the prerequisites; never assume it. Live mode is governed by these rules
(details and exact command allow/deny lists live in the infra playbooks):

- **Read-only commands ONLY.** Never run anything that mutates infrastructure, state,
  or the repo (no `apply/create/delete/patch/edit/scale/exec/port-forward`,
  `reconcile/suspend/resume/bootstrap`, `up/destroy/import/config set/state`,
  `git commit/push/checkout/clean`).
- **Confirm the target before any cluster command.** Print the active kube context +
  namespace (or Pulumi stack) and confirm with the user it's the intended
  environment, so production is never touched by accident.
- **Fail-stop, never fall back blindly.** If a command fails on access (wrong/no
  context, not authenticated, missing passphrase), STOP and tell the user exactly
  what to set up. Don't retry blindly or silently revert.
- **Never reveal secret VALUES.** Even in live mode, never retrieve, decrypt, or
  display plaintext secret material, and never write a secret value into either
  deliverable. No `kubectl get secret -o yaml|json` (existence + metadata only), no
  `pulumi stack export` of secret material, no `--show-secrets` flags. Prefer
  non-secret reads. Record *that* a secret exists and *where* it's referenced —
  never its plaintext.
- Anything still unreadable stays **`VERIFY`**. Live mode never modifies the repo or
  the infrastructure — it only *reads*.

---

## The workflow (every run)

```
Phase 0  Read intent docs → detect project type → announce the playbook
Phase 1  Read-only INVENTORY  → STOP, present it, wait for confirmation   ← mandatory gate
Phase 2  Build all three deliverables, sliced by the Phase-0 axis
Phase 3  Self-verify (spot-check citations + headless-render both HTMLs)
```

Track these as TODOs so the gate isn't skipped.

---

## Phase 0 — Detect the project type

### Step 0a — Read intent & convention docs first (when present)

Before scanning for project-type markers, read any of the following files that
exist in the repo. They provide **intent and convention context** — domain
vocabulary, module boundaries, known decisions — that sharpens the inventory in
Phase 1 and the diagrams in Phase 2.

Files to look for (not all will exist — skip gracefully if absent):

| File / path | What to extract |
|---|---|
| `CLAUDE.md`, `AGENTS.md`, `.cursorrules` | Coding conventions, off-limit areas, project vocabulary |
| `README.md` (root or per-package) | Purpose, entry points, how to run |
| `ARCHITECTURE.md` | Module boundaries, design decisions |
| `CONTRIBUTING.md` | Workflow, naming conventions |
| `docs/**` (any `.md`) | ADRs, runbooks, guides |
| Files named `ADR-*.md`, `adr-*.md`, or inside `docs/decisions/`, `docs/adr/` | Architectural decision records |

**Treat these as SECONDARY to code.** They guide where to look and provide
vocabulary; they do not override what the code actually does. Apply this rule
consistently:

- If a doc says something that matches the code → use it freely as context.
- If a doc contradicts the code → trust the code. Flag the gap as:
  > `VERIFY — CLAUDE.md says X; code at path:line shows Y`
  Collect all such flags in the VERIFY list (§12 of SYSTEM_FLOW.md).
- If a doc claims something you cannot confirm in the code → tag it `VERIFY`.
- If no doc files exist → proceed directly to marker detection below.

Do **not** change your grounding discipline: every claim in the deliverables still
cites a real `path:line`. Docs add vocabulary, not citations.

---

### Step 0b — Detect the project type

Inspect manifests and signature files, **scanning recursively** (key marker files
are often nested in subdirectories, e.g. `Pulumi.yaml` under `tenants/<x>/`, or
Flux `kustomization.yaml` under `clusters/<env>/`). Do not judge from the repo
root alone.

Check, **in this order** (IaC markers win over language detection — a Pulumi
program is TypeScript but is *not* a backend):

| Look for | → Playbook | Load |
|---|---|---|
| `Pulumi.yaml` / `Pulumi.<stack>.yaml`, or `@pulumi/*` in `package.json`/`requirements` | **Pulumi** | `references/pulumi.md` |
| `flux-system/`, `gotk-components.yaml`, `HelmRelease`/`Kustomization` CRDs, `clusters/<env>/` overlays | **Flux / GitOps** | `references/flux.md` |
| `*.tf` / `.terraform/`, CloudFormation `*.template.{json,yaml}`, `serverless.yml`, Helm `Chart.yaml` (standalone), raw k8s manifests | **Generic IaC** | `references/iac.md` |
| A server framework + routes/handlers: Express/Nest/Fastify (Node), FastAPI/Flask/Django (Python), Gin/net-http (Go), Spring (Java), Rails (Ruby), etc. — and **no** significant client app | **Backend / API** | `references/backend.md` |
| A client app: React/Vue/Svelte/Angular + a bundler (Vite/Webpack/Next), routes + components + API client — and **no** significant server | **Frontend / SPA** | `references/frontend.md` |
| Both a server app AND a client app (monorepo, or `apps/`+`libs/`, or `frontend/`+`backend/`) | **Full-stack** | `references/fullstack.md` |

Detection tips:
- Read `package.json` **dependencies**, not just file extensions — `@pulumi/aws`
  means Pulumi even though the code is `.ts`; `react`+`vite` means frontend;
  `@nestjs/*`/`express`/`fastify` means backend.
- For Python: `pyproject.toml`/`requirements.txt` deps (`fastapi`, `flask`,
  `django`, `celery`) classify the backend. The backend playbook is
  **framework-agnostic** — never assume a specific framework's constructs.
- A repo can be ambiguous. If two playbooks plausibly apply (e.g. a Next.js app
  with API routes), say so, pick the dominant one, and note that you'll fold in the
  secondary axis. When genuinely unsure, ask the user before continuing.

**Announce the result**, e.g.: *"Detected a Flux GitOps repo (clusters/ with
staging + production overlays). Using the Flux playbook — I'll slice by
environment."* Include a one-line note on any doc files read in Step 0a and
whether any doc↔code contradictions were found.

---

### Step 0c — Determine the output directory and load prior state

**Compute `DOCS_DIR`** (every run, before any other action):

> **`$SKILL_DIR`** — throughout this skill, this is the absolute path of this
> skill's own directory (the folder containing `scripts/`, `assets/`, and this
> `SKILL.md`). Resolve it once, then substitute it in every command below:
> - **Claude Code plugin install:** `SKILL_DIR="${CLAUDE_PLUGIN_ROOT}/skills/system-flow-mapper"`
> - **Otherwise** (`npx skills`, manual copy, or any other agent): it's the
>   folder this `SKILL.md` lives in. If you don't already know that path, discover
>   it from a bundled marker file:
>   `SKILL_DIR="$(cd "$(dirname "$(find "$HOME" -type f -path '*system-flow-mapper/scripts/get_docs_dir.py' 2>/dev/null | head -1)")/.." && pwd)"`

```sh
DOCS_DIR=$(python3 $SKILL_DIR/scripts/get_docs_dir.py .)
```

This returns `docs/system-flow/` inside the analyzed project — a stable location,
so re-runs reuse `state.json` for incremental updates. Announce:
*"Docs directory: `<DOCS_DIR>`"*.

Because these generated files live inside the repo, **ask the user once**:
*"Add `docs/system-flow/` to `.gitignore` so the generated docs aren't committed,
or keep them tracked?"* If they choose to ignore, append `docs/system-flow/` to
the project's `.gitignore` (create it only if they want). This is the only project
file this skill may modify — never touch source.

All deliverables write to this directory:
- `${DOCS_DIR}/SYSTEM_FLOW.md`
- `${DOCS_DIR}/system-flow.html`
- `${DOCS_DIR}/system-flow-technical.html`

Per-section fragment files persist in `${DOCS_DIR}/fragments/` (written during
Phase 2, read on incremental runs):
- `fragments/<name>-md.md` — SYSTEM_FLOW.md content for this section
- `fragments/<name>-plain.html` — plain-language HTML section body
- `fragments/<name>-tech.html` — technical HTML actor/reference panel body

Where `<name>` is the section's short identifier (e.g. `public`, `admin`,
`traces`, `data-model`). The section order is the order they appear in the
final documents.

**Check for prior state** — look for `${DOCS_DIR}/state.json`:

**Case A — No `state.json` (first run, or file missing/corrupt):** proceed normally
through Phases 1–3.

**Case B — `state.json` found (incremental run):** read `commit` from it, then:

```sh
git diff --name-only <state.commit>..HEAD
```

If the diff is empty (no new commits since last run), tell the user the docs are
already up to date and stop.

Otherwise, classify each section in `state.json["sections"]` as **stale** or
**clean** by checking whether any changed file path has a prefix that appears in
that section's `paths` list (literal prefix match, not glob):
- A section with an empty `paths` list (`[]`) is **always stale** when anything else
  changed — this covers cross-cutting reference sections like traces and data-model.
- A section is **clean** only if none of its prefixes match any changed file.

Announce: *"Incremental run — stale: [names], clean: [names]. Skipping Phase 1
inventory confirmation for clean sections."*

In Phase 2 (incremental run):
- **Stale sections:** re-read their source files, regenerate all three fragment files.
- **Clean sections:** read existing fragment files from `${DOCS_DIR}/fragments/` — do
  **not** re-read their source files.
- Rebuild both HTML files in full from all fragments via `build_html.py` — never
  surgically edit the 3.3 MB assembled HTML.

---

## Phase 1 — Inventory, then STOP (mandatory gate)

Before building anything, do a quick read-only pass to produce an **inventory**,
then **stop and present it to the user for confirmation**. The per-type reference
file lists exactly what to inventory for that playbook; in general it is:

- the **slice axis** (actors/roles for apps; environments+components for IaC) and
  the concrete list of values on that axis;
- the **surface**: routes/endpoints, pages, or resources/modules — counted and
  grouped;
- **data stores** and the **data model** entities;
- **async / out-of-band** paths (queues, events, websockets, schedulers, CI/CD,
  reconciliation loops);
- **entry points** and how a request/change enters and flows through;
- a first pass at **security / tech-debt** smells to chase down.

Then present a short summary: *"Here's what I found and how I'd slice the
docs — X actors/environments, Y endpoints/resources, these diagrams. Confirm and
I'll build both files, or tell me what to adjust."*

**Why this gate matters:** the whole value is slicing the documentation along the
axis that matches how people actually reason about this system. Slicing wrong (by
the wrong roles, or per-resource when the user thinks per-environment) wastes a
large build and produces a doc nobody uses. A 30-second confirmation prevents
building the wrong thing. **Do not skip it in interactive use.** (In a
non-interactive / automated run where no human can answer, record the inventory in
the doc and proceed.)

---

## Phase 2 — Build the two deliverables

Open the routed reference file and follow it — it defines the section structure,
the required diagrams, and the slice axis for that project type. The references
share these rules:

### Grounding discipline (non-negotiable)
- **Every claim cites a real `path:line`.** If you state that an endpoint exists,
  a resource is public, or two tables relate — point at the file.
- **Never fabricate.** No invented endpoints, resources, env vars, or relations.
  If you didn't read it, you don't claim it.
- **Tag uncertainty `VERIFY`** with what you'd need to confirm it, and collect
  these in an "Open questions / VERIFY list" section. Honest gaps beat confident
  fiction.

### Diagrams are Mermaid only
- `sequenceDiagram` for request/response and event flows. Match the gold-standard
  **arrow-payload** style: put the method/path/payload on the arrow, e.g.
  `FE->>API: POST /things {CreateThingDto}<br/>Authorization: Bearer {token}` and
  `API-->>FE: { data, errors }`. Use `participant` aliases and `Note over` for
  context. **In sequence-arrow text, avoid bare `<...>` and unmatched `()`** —
  Mermaid's sequence parser reads `<...>` as markup and errors out (`<br/>` is the
  one safe tag); use `{token}`, `[id]`, or plain words instead.
- `flowchart TD` / `graph TD` for capability maps and architecture/topology.
- `erDiagram` for data models (with cardinality and key attributes per entity).
- Keep each diagram focused; prefer several readable diagrams over one giant one.

### Mandatory "Known issues / tech debt" section
A dedicated section in the `.md` collecting security-relevant and correctness
findings — the **do-not-carry-over list**. Rate severity, cite the file, explain
the impact. For IaC, this is where public buckets, open ingress, broad IAM/RBAC,
hardcoded secrets, and missing encryption go.

### Fragment discipline (required for incremental updates)

As you generate each section, write it to three persistent fragment files in
`${DOCS_DIR}/fragments/`:
- `<name>-md.md` — this section's SYSTEM_FLOW.md content
- `<name>-plain.html` — this section's body content for `system-flow.html`
- `<name>-tech.html` — this actor/reference panel for `system-flow-technical.html`

Where `<name>` is the section's short identifier (e.g. `public`, `admin`, `traces`,
`data-model`). On a first run, write all fragments. On an incremental run, re-write
only stale-section fragments and read clean-section fragments from disk.

Before assembling each HTML, concatenate all `*-plain.html` fragments (in section
order) into `${DOCS_DIR}/fragments/plain-body.html`, and all `*-tech.html` fragments
into `${DOCS_DIR}/fragments/tech-body.html`.

### HTML deliverable 1 — plain-language companion
Build the `.md` first, then translate it into the plain-language companion. The HTML
is for someone non-technical: **no routes, DTOs, HTTP verbs, resource ARNs, class
names, or file paths.** Translate everything to everyday terms. See
`references/html-template.md` for the section pattern, the diagram color palette,
and how to assemble the file.

**Assembling the plain HTML:**
```sh
python3 $SKILL_DIR/scripts/build_html.py \
  --content "${DOCS_DIR}/fragments/plain-body.html" \
  --output  "${DOCS_DIR}/system-flow.html" \
  --title   "How <Project> Works, In Plain Language"
```

### HTML deliverable 2 — technical interactive reference
After the plain companion, produce the technical interactive HTML from the same
`SYSTEM_FLOW.md` findings. This is **for engineers**: searchable endpoint cards with
color-coded HTTP method badges and role chips, actor-scoped sidebar navigation,
rendered sequence diagrams, and a light/dark toggle — all offline. See
`references/html-technical.md` for the fragment structure, the JS selector contract,
and endpoint-card rules.

**Assembling the technical HTML** (pass `--shell` to use the interactive shell):
```sh
python3 $SKILL_DIR/scripts/build_html.py \
  --content "${DOCS_DIR}/fragments/tech-body.html" \
  --output  "${DOCS_DIR}/system-flow-technical.html" \
  --title   "<Project> — Technical Reference" \
  --shell   $SKILL_DIR/assets/html-technical-shell.html
```

Do **not** try to write either HTML by hand — the Mermaid bundle is ~3.3MB.
Both resulting files are ~3.3MB by design (the price of true offline capability).

---

## Phase 3 — Self-verify before declaring done

1. **Spot-check 3–5 claims** against source — open the cited files and confirm the
   endpoint/resource/relation actually says what the doc says. Fix or `VERIFY`-tag
   anything that doesn't hold.
2. **Headless-render both HTML files offline.** Use the Playwright MCP:
   - Navigate to `file://<abs path>` for each file (no network/CDN dependency).
     If your headless tool blocks the `file:` protocol, serve `$DOCS_DIR` with a
     localhost static server (`python3 -m http.server` from that dir) and open
     `http://127.0.0.1:<port>/<file>` — still fully offline, no CDN.
   - Wait for `svg` elements inside `.mermaid` / `.diagram-wrap` to appear.
   - Check the console for Mermaid parse errors.
   - For the technical HTML: also verify that panel switching works (click a nav
     item, confirm the correct `.actor-panel` becomes visible).
   - If a diagram fails, the usual cause is a Mermaid syntax slip — fix the
     fragment and rebuild.
3. Confirm all three files cross-link each other (relative `./` links work because
   they all live in the same `${DOCS_DIR}`), and the `.md` has its full
   table-of-contents and the tech-debt + VERIFY sections.
4. **Write `${DOCS_DIR}/state.json`** with the current HEAD commit, today's date,
   and a per-section entry for every section generated (stale or clean):
   ```json
   {
     "commit": "<git rev-parse --short HEAD>",
     "mappedAt": "<YYYY-MM-DD>",
     "sections": [
       { "name": "public",     "paths": ["src/auth", "app/api/auth"] },
       { "name": "admin",      "paths": ["src/admin"] },
       { "name": "traces",     "paths": [] },
       { "name": "data-model", "paths": ["src/models", "src/entities", "prisma"] }
     ]
   }
   ```
   `paths` contains the **directory prefixes** in the project repo that, when changed,
   should cause this section to be regenerated on the next run. Use your Phase 1
   module-boundary knowledge to fill these in. Sections that span everything (traces,
   ER diagrams, tech-debt lists) should have `"paths": []` so they always rebuild
   when any sibling section rebuilds. Section order in the array must match the order
   of the actual document sections.

---

## Reference files (load the one Phase 0 routed to)

| File | When |
|---|---|
| `references/backend.md` | Backend / API services (any language/framework) |
| `references/frontend.md` | Client SPAs / web frontends |
| `references/fullstack.md` | Monorepos / repos with both a backend and a frontend |
| `references/pulumi.md` | Pulumi infrastructure programs |
| `references/flux.md` | Flux / GitOps Kubernetes config repos |
| `references/iac.md` | Generic IaC: Terraform, CloudFormation, serverless, Helm |
| `references/html-template.md` | Always — plain-language companion (HTML deliverable 1) |
| `references/html-technical.md` | Always — interactive technical reference (HTML deliverable 2) |

A worked, gold-standard example of both deliverables (a NestJS + React monorepo)
is the reference for *depth and style*. The structure and discipline generalize;
the content does not — never carry a previous project's specifics into a new one.
