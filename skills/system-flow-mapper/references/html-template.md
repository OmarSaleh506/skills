# Reference: The plain-language HTML companion

`system-flow.html` (in `$DOCS_DIR/`) is the non-technical twin of `SYSTEM_FLOW.md`. Same truths,
zero jargon, and it must open by **double-click and work fully offline** (the
Mermaid engine is inlined). Build the `.md` first, then translate it down to this.

## The golden rule: no jargon

The reader is a stakeholder, a manager, a new teammate on day one — not an engineer.
**Strip every technical token** and translate to everyday language:

| In the .md (technical) | In the .html (plain) |
|---|---|
| `POST /api/v1/app/trips/reserve`, DTOs, HTTP verbs | "when a customer reserves a spot on a trip" |
| JWT / access token / guard / middleware | "the system checks who you are and what you're allowed to do" |
| `erDiagram`, foreign keys, tables | "the information the system keeps about each thing" |
| `Kustomization`, `HelmRelease`, reconciliation | "the staging copy and the live copy of the system, kept in sync automatically" |
| resource ARNs, security groups, IAM | "where things run and who's allowed to reach them" |
| Bull queue / event emitter | "work that happens quietly in the background" |

No routes, no DTO/class names, no file paths, no provider resource types. If a
sentence needs a code font, it doesn't belong in the HTML.

## Section pattern

A header, a short table of contents, then one card-like `<section>` per idea. Adapt
the set to the project type:

- **Apps (backend/frontend/full-stack):**
  1. *The big picture* — "How a request travels through the system" (the 5 steps:
     person acts → system checks who they are → checks what they're allowed → does
     the work → person sees the result), with one simple `flowchart LR`.
  2. *The cast* — the kinds of people who use it, as friendly cards.
  3. One section **per actor** — what they do, a plain bullet list, and a
     `flowchart TD` of their journey.
  4. *How realtime/notifications work* (if applicable).
  5. *How the system keeps things safe* — the guarantees in plain terms.
- **Infra (Pulumi/Flux/IaC):**
  1. *The big picture* — what this infrastructure is and what it runs, one diagram.
  2. *The environments* — "a practice copy (staging) and the real one (production)",
     and how they differ in plain terms.
  3. *How a change goes live* — the promotion/deploy path as a friendly flow.
  4. *The main pieces* — components in everyday language (the database, the cluster,
     the front door / load balancer, DNS as "the address book").
  5. *How it stays safe and in sync* — guarantees, and a gentle pointer that the
     technical doc lists known gaps.

Always: a header with an `eyebrow`, an `<h1>`, a `lead` paragraph, a `toc`, and a
footer that links back to `SYSTEM_FLOW.md` and says the page works offline.

## How to build it (don't hand-write the file)

Write a **body fragment** (everything that goes inside `.container`: the `<header>`,
the `<section>`s, the `<footer>`) to a scratch file, with each diagram as
`<pre class="mermaid">…</pre>`. Then assemble:

```sh
# Concatenate plain-HTML section fragments into the body file first (see SKILL.md § Fragment discipline)
python3 $SKILL_DIR/scripts/build_html.py \
  --content "${DOCS_DIR}/fragments/plain-body.html" \
  --output  "${DOCS_DIR}/system-flow.html" \
  --title   "How <Project> Works, In Plain Language"
```

The script inlines the pinned Mermaid bundle and the CSS shell → one ~3.3MB
self-contained file. Never paste the Mermaid bundle yourself.

## Diagram palette (use these classDefs)

Plain-language diagrams use soft shapes and a consistent palette. Put `classDef`
lines at the end of each diagram:

```
classDef p fill:#e6f0f7,stroke:#1e6091,stroke-width:2px,color:#1a2230;
classDef s fill:#ffffff,stroke:#b3c0cf,stroke-width:1.5px,color:#1a2230;
classDef w fill:#fdfdfb,stroke:#d6dbe2,stroke-width:1px,color:#1a2230;
classDef db fill:#f6f7f5,stroke:#a9b1bb,stroke-dasharray:4 3,color:#5a6573;
```
- `:::p` person/actor (rounded `([ ])`), `:::s` a system step, `:::w` a thing they
  can do / a component, `:::db` saved/looked-up information (use `[( )]`).
- Keep labels short and plain; use `<br/>` for line breaks. Prefer `flowchart LR`/`TD`.
  Avoid `sequenceDiagram` here — it's too technical-looking for this audience.

## Worked fragment (structure to imitate, not content to copy)

```html
<header class="page">
  <p class="eyebrow">Acme • System overview</p>
  <h1>How Acme Works, In Plain Language</h1>
  <p class="lead">Acme is an app for … . This page explains, without technical jargon,
     what each kind of person can do and what happens behind the scenes.</p>
  <p class="lead">For the technical version with code references, see
     <a href="./SYSTEM_FLOW.md" style="color:var(--accent);font-weight:600;">SYSTEM_FLOW.md</a>.</p>
  <nav class="toc" aria-label="Table of contents">
    <strong>What's on this page</strong>
    <ul>
      <li><a href="#travel">How a request travels through the system</a></li>
      <li><a href="#people">The kinds of people who use Acme</a></li>
      <!-- … one per section … -->
    </ul>
  </nav>
</header>

<section class="intro" id="travel">
  <span class="label">The big picture</span>
  <h2>How a request travels through the system</h2>
  <p>Every time someone taps a button or sends a form, the same few things happen…</p>
  <div class="diagram">
<pre class="mermaid">
flowchart LR
  A([Person uses<br/>the app]):::p --> B[The system checks<br/>who they are]:::s
  B --> C[The system checks<br/>what they're allowed to do]:::s
  C --> D[The system does<br/>the actual work]:::s
  D -.- E[(Information saved<br/>or looked up)]:::db
  D --> F([The person<br/>sees the result]):::p
  classDef p fill:#e6f0f7,stroke:#1e6091,stroke-width:2px,color:#1a2230;
  classDef s fill:#ffffff,stroke:#b3c0cf,stroke-width:1.5px,color:#1a2230;
  classDef db fill:#f6f7f5,stroke:#a9b1bb,stroke-dasharray:4 3,color:#5a6573;
</pre>
  </div>
</section>

<footer class="page">
  Acme system overview · plain-language companion to
  <a href="./SYSTEM_FLOW.md" style="color:var(--accent);">SYSTEM_FLOW.md</a> ·
  this page works fully offline
</footer>
```

Available CSS classes (from the shell): `container`, `page` (header/footer),
`eyebrow`, `lead`, `toc`, `section` (+ `intro` variant), `label`, `grid-people` +
`person`, `ul.plain`, `diagram`, `pill`. You don't need any other styling.

## Before you're done
- Re-read every section as if you knew nothing about software. Any leftover jargon?
- Confirm the build script reported the expected diagram count.
- Headless-render and confirm each `<pre class="mermaid">` became an `<svg>` with no
  console errors and no network requests (see SKILL.md Phase 3).
