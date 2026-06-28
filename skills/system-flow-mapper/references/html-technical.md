# Reference: The technical interactive HTML companion

`system-flow-technical.html` (in `$DOCS_DIR/`) is the developer-facing twin of `SYSTEM_FLOW.md`.
It exposes the same information in an interactive, searchable, offline-capable format:
a sticky sidebar to navigate by actor/role, expandable endpoint cards with method
badges and role chips, rendered sequence diagrams, and a light/dark toggle. It is
**for engineers and technical reviewers**, not for general audiences.

Build `SYSTEM_FLOW.md` first. This file is translated from it — never invented.

---

## What goes in this HTML (vs the plain-language companion)

| Feature | `html-technical.md` (this file) | `html-template.md` (plain companion) |
|---|---|---|
| Audience | Developers, reviewers | Stakeholders, managers |
| Endpoint cards | Yes — method, path, role, schema | No |
| Sequence diagrams | Yes — technical, arrow-payload style | Flowcharts only, jargon-free |
| ER / data model | Yes | No |
| Jargon | Yes — routes, DTOs, HTTP verbs, JWT | Stripped out |
| File name | `$DOCS_DIR/system-flow-technical.html` | `$DOCS_DIR/system-flow.html` |

---

## Shell contract — what the assembler expects

The technical shell (`assets/html-technical-shell.html`) provides the topbar
(search, theme toggle, docs link) and all interactive JavaScript. The body fragment
you write fills the `__CONTENT__` placeholder inside `.app-body`.

**The JS selectors the shell depends on — write the fragment to match these exactly:**

| Class / attribute | Purpose |
|---|---|
| `.sidebar` | The left navigation pane |
| `.sidebar-hdr` | Sidebar header (project name + subtitle) |
| `.proj-name`, `.proj-sub` | Sidebar title elements |
| `.sidebar-nav` | Scroll container for nav sections |
| `.nav-section` | A group of nav items |
| `.nav-section-lbl` | Group label ("Actors", "Reference") |
| `.nav-item[data-target="PANEL_ID"]` | Clickable actor link — `data-target` must match a panel `id` |
| `.nav-ico`, `.nav-lbl`, `.nav-cnt` | Icon, label, count badge inside `.nav-item` |
| `.content-wrap` | The scrollable main content area |
| `.actor-panel[id="PANEL_ID"]` | A content panel (one per actor + one per reference section) |
| `.endpoint-card[data-method][data-path][data-role]` | An endpoint card — all three data attrs drive search |
| `.ep-head` | Clickable header of an endpoint card (triggers expand) |
| `.expand-btn` | The `▾` / `▴` toggle inside `.ep-head` |
| `.ep-body` | Hidden detail area (shown when `.expanded` is toggled by JS) |
| `.mermaid` | Mermaid diagram blocks (rendered by `mermaid.init` before first paint) |

**Do not add `hidden` or `display:none` to panels in the HTML** — the shell's JS
hides non-active panels before the first browser paint, after Mermaid has rendered
all diagrams. Setting `hidden` in HTML would prevent Mermaid from rendering diagrams
in those panels.

---

## Fragment structure

Write everything that goes inside `.app-body`: first the `<aside>`, then the
`.content-wrap` with all panels.

```html
<aside class="sidebar" role="navigation" aria-label="Actor navigation">
  <div class="sidebar-hdr">
    <span class="proj-name">Project Name</span>
    <span class="proj-sub">v1.0 · FastAPI / backend</span>
  </div>
  <nav class="sidebar-nav" aria-label="Actors and sections">

    <div class="nav-section">
      <div class="nav-section-lbl">Actors</div>
      <!-- One .nav-item per actor — data-target must match a panel id -->
      <a class="nav-item" data-target="panel-public" href="#panel-public">
        <span class="nav-ico" aria-hidden="true">○</span>
        <span class="nav-lbl">Anonymous Public</span>
        <span class="nav-cnt" title="endpoints">9</span>
      </a>
      <!-- … more actors … -->
    </div>

    <div class="nav-section">
      <div class="nav-section-lbl">Reference</div>
      <a class="nav-item" data-target="panel-traces" href="#panel-traces">
        <span class="nav-ico" aria-hidden="true">⟶</span>
        <span class="nav-lbl">End-to-End Traces</span>
      </a>
      <a class="nav-item" data-target="panel-data-model" href="#panel-data-model">
        <span class="nav-ico" aria-hidden="true">⬡</span>
        <span class="nav-lbl">Data Model</span>
      </a>
    </div>

  </nav>
</aside>

<div class="content-wrap" role="main">

  <!-- ── Actor panel: Anonymous Public ── -->
  <div class="actor-panel" id="panel-public">
    <div class="panel-hdr">
      <div class="panel-crumb">Actor</div>
      <h1 class="panel-title">Anonymous Public</h1>
      <p class="panel-desc">No token required. Mutation routes are gated by Google reCAPTCHA v3.</p>
      <div class="panel-chips">
        <span class="chip">Keycloak group: <code>none</code></span>
        <span class="chip">Auth: <code>none</code></span>
      </div>
    </div>

    <!-- Capability diagram (flowchart from SYSTEM_FLOW.md §8) -->
    <div class="diagram-block">
      <div class="block-lbl">Capability flow</div>
      <div class="diagram-wrap">
        <pre class="mermaid">
flowchart TD
  PUB([Anonymous Visitor]) --> A1[View public content]
  PUB --> A2[Submit applications — reCAPTCHA required]
        </pre>
      </div>
    </div>

    <!-- Endpoint section — grouped by module -->
    <div class="section-row">
      <h2 class="section-hd">Endpoints</h2>
      <span class="section-meta">9 endpoints</span>
    </div>

    <div class="ep-group">
      <div class="ep-group-hd">User &amp; Auth</div>

      <!-- Each endpoint card: data-method, data-path, data-role drive search -->
      <div class="endpoint-card" data-method="post" data-path="/user/register" data-role="public">
        <div class="ep-head">
          <span class="mbadge post">POST</span>
          <span class="ep-path">/user/register</span>
          <span class="rcip cap">Public + reCAPTCHA</span>
          <span class="expand-btn">▾</span>
        </div>
        <div class="ep-body">
          <div class="dtl-section">
            <div class="dtl-lbl">Request Body</div>
            <table class="ftable">
              <thead><tr><th>Field</th><th>Type</th><th>Required</th><th>Notes</th></tr></thead>
              <tbody>
                <tr><td><code>email</code></td><td>string</td><td>✓</td><td></td></tr>
                <tr><td><code>password</code></td><td>string</td><td>✓</td><td></td></tr>
                <tr><td><code>name</code></td><td>string</td><td>✓</td><td></td></tr>
              </tbody>
            </table>
          </div>
          <div class="dtl-section">
            <div class="dtl-lbl">Response</div>
            <pre class="code-block">201 { "user_id": "uuid" }</pre>
          </div>
          <div class="dtl-section">
            <div class="dtl-lbl">Side Effects</div>
            <ul class="fx-list">
              <li>Creates user in Keycloak, then inserts into <code>users</code> table.</li>
              <li>Dispatches <code>send_email_task</code> (welcome email) via Celery.</li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Endpoint with no documented schema → use VERIFY -->
      <div class="endpoint-card" data-method="get" data-path="/theme" data-role="public">
        <div class="ep-head">
          <span class="mbadge get">GET</span>
          <span class="ep-path">/theme</span>
          <span class="rcip pub">Public</span>
          <span class="expand-btn">▾</span>
        </div>
        <div class="ep-body">
          <div class="dtl-section">
            <div class="dtl-lbl">Request</div>
            <p>No body. No auth.</p>
          </div>
          <div class="dtl-section">
            <div class="dtl-lbl">Response</div>
            <p><span class="vtag">VERIFY</span> — full schema not documented in SYSTEM_FLOW.md §6; see <code>app/api/common/routes.py</code>.</p>
          </div>
        </div>
      </div>

    </div><!-- /.ep-group -->
  </div><!-- /.actor-panel #panel-public -->

  <!-- ── End-to-End Traces panel ── -->
  <div class="actor-panel" id="panel-traces">
    <div class="panel-hdr">
      <div class="panel-crumb">Reference</div>
      <h1 class="panel-title">End-to-End Traces</h1>
      <p class="panel-desc">Sequence diagrams for representative request paths, from client to persistence layer.</p>
    </div>

    <div class="trace-card">
      <div class="trace-hdr">
        <div class="trace-ttl">Trace A — Public form submission</div>
        <div class="trace-sub">e.g. POST /plus/application with reCAPTCHA</div>
      </div>
      <div class="trace-body">
        <div class="diagram-wrap">
          <pre class="mermaid">
sequenceDiagram
  participant U as User
  participant API as Garage API
  API->>U: 200 OK
          </pre>
        </div>
      </div>
    </div>

  </div><!-- /.actor-panel #panel-traces -->

  <!-- ── Data Model panel ── -->
  <div class="actor-panel" id="panel-data-model">
    <div class="panel-hdr">
      <div class="panel-crumb">Reference</div>
      <h1 class="panel-title">Data Model</h1>
      <p class="panel-desc">Entity relationships derived from SQLAlchemy ORM models.</p>
    </div>

    <div class="diagram-block">
      <div class="block-lbl">Core entity relationships</div>
      <div class="diagram-wrap">
        <pre class="mermaid">
erDiagram
  User ||--o{ Booking : "creates"
        </pre>
      </div>
    </div>
  </div><!-- /.actor-panel #panel-data-model -->

</div><!-- /.content-wrap -->
```

---

## Endpoint card rules

### What to fill in

Use only what is stated in `SYSTEM_FLOW.md`:

| Card field | Source in SYSTEM_FLOW.md |
|---|---|
| Method | §5 endpoint tables |
| Path | §5 endpoint tables |
| Required role | §5 endpoint tables (SA, A, auth, pub, reCAPTCHA) |
| Request body | §6 "Common create/update schemas" |
| Response shape | §6 or §7 traces |
| Side effects | §6 "Side-effect catalogue" |

**If a field has no entry in SYSTEM_FLOW.md**, write:
```html
<span class="vtag">VERIFY</span> — not documented in SYSTEM_FLOW.md §6; see <code>path/to/file.py</code>
```
Never invent plausible-looking field names. The VERIFY tag is the correct output.

### `data-role` values (drive search highlighting)

| Role string | Use when |
|---|---|
| `public` | No auth required AND no reCAPTCHA |
| `captcha` | No auth but reCAPTCHA required |
| `auth` | Any valid JWT (`login_required`) |
| `admin` | One or more admin roles but not SA-only |
| `sa` | GARAGE_SUPER_ADMIN required |
| `mixed` | Multiple disjoint roles (e.g. SA/A/SERVICE) |

### Method badge classes

`get` `post` `put` `delete` `patch` — lowercase, match the HTTP verb.

### Role chip classes

`pub` `cap` (reCAPTCHA) `auth` `admin` `sa` `mixed`

---

## Diagrams in the technical HTML

All diagrams come from `SYSTEM_FLOW.md` — copy them verbatim. Do not rewrite or
abbreviate. Use:
- `sequenceDiagram` (with arrow-payload style) for traces and per-actor sequences
- `flowchart TD` for capability maps
- `erDiagram` for the data model

Wrap each in `.diagram-wrap`:
```html
<div class="diagram-wrap">
  <pre class="mermaid">
<!-- paste diagram here -->
  </pre>
</div>
```

Do **not** add `classDef` lines from the plain-language companion — those palette
rules are irrelevant here; the shell's Mermaid theme handles styling.

---

## How to build it

Write the body fragment yourself, then assemble it with `build_html.py` (below).
This is the primary, portable path — it needs nothing beyond this skill.

> **Optional, for very large APIs:** if a codebase has far more endpoints than is
> practical to hand-author, write a small throwaway script *in that target repo*
> that scans its route decorators (e.g. `@router.(get|post|put|delete|patch)`),
> classifies each route into a panel, renders the cards, then calls
> `build_html.py`. No such generator ships with this skill — build one to fit the
> target codebase only if you need it, and keep the card count equal to the real
> handler count.

### Manual / curated approach

Write the body fragment (the `<aside>` + `.content-wrap` and all child panels) to
a scratch file, then assemble with the technical shell:

```sh
# Concatenate technical HTML panel fragments into the body file first (see SKILL.md § Fragment discipline)
python3 $SKILL_DIR/scripts/build_html.py \
  --content "${DOCS_DIR}/fragments/tech-body.html" \
  --output  "${DOCS_DIR}/system-flow-technical.html" \
  --title   "<Project> — Technical Reference" \
  --shell   $SKILL_DIR/assets/html-technical-shell.html
```

The script accepts `--shell` to override the default plain-language shell. The
resulting file is ~3.3MB (Mermaid inlined). It works fully offline.

---

## COVERAGE rule — no silent dropping or fabrication

**Source of truth**: `@router.(get|post|put|delete|patch)` decorators in `app/api/`,
not SYSTEM_FLOW.md §5 tables (which elide many routes with "…" summaries).

- Card count MUST equal the grep count of real route decorators.
- For request/response: pull from §6. Where unknown → show `VERIFY` tag.
- **Never invent** plausible-looking field names to fill a card.
- If §6 doesn't document a schema, the correct output is the VERIFY tag + source file path.

## Adapting to non-API projects (IaC / Flux / infra)

This reference is written for HTTP APIs. For projects with **no HTTP endpoints**,
keep the same shell and selectors but remap the concepts:

- **Actors → top-level groupings:** environments/clusters (Flux), stacks/components
  (Pulumi/IaC). Each still gets a sidebar nav item + an `.actor-panel`.
- **Endpoint cards → resource cards:** one card per resource / component / HelmRelease.
  Keep the `.endpoint-card` class, and set `data-method` / `data-path` / `data-role`
  to meaningful infra values (e.g. kind / resource name / environment) so search and
  filtering still work.
- **COVERAGE source of truth → the manifest/resource inventory** from `SYSTEM_FLOW.md`
  (not `@router` decorators). Card count should match the real resource/component
  count, with `VERIFY` where a value is live-only.

## Checklist before declaring done

_(For non-API projects, read "endpoint card" as "resource card" and the `@router`
count as the resource/component count — see the section above.)_

- [ ] Every actor from `SYSTEM_FLOW.md §2` has a sidebar nav item and a panel.
- [ ] Card count matches `grep -rn "@router\.(get|post|put|delete|patch)"` count from `app/api/`.
- [ ] Every endpoint card has a Request Body **and** a Response section — even if both show `VERIFY`.
- [ ] Endpoint cards without schema documentation in §6 show `VERIFY` — not guessed fields.
- [ ] All diagrams from §7 (traces), §8 (per-role), and §9 (ER) are in the fragment, copied verbatim.
- [ ] `data-method`, `data-path`, and `data-role` are set on every `.endpoint-card` —
      these are required for search to work.
- [ ] No `hidden` attribute on any `.actor-panel` in the HTML — the shell's JS sets
      visibility before the first paint.
- [ ] Headless-render passes: all `.mermaid` blocks become `<svg>` with no console errors.
- [ ] Shell `themeVariables` covers flowchart, sequence, AND erDiagram keys for both dark and light.
