# Playbook: Flux / GitOps (Kubernetes config repo)

For a **GitOps** repository that Flux CD reconciles into one or more Kubernetes
clusters. The repo *is* the desired state; Flux continuously applies it. The map you
produce centers on **environments and how they differ**, the **reconciliation flow**,
and the **promotion path** from lower to higher environments.

> Phase-0 caution: this looks like "a pile of YAML manifests" but it is not — the
> tells are `flux-system/`, `gotk-components.yaml`, `HelmRelease`/`Kustomization`
> (`kustomize.toolkit.fluxcd.io` / `helm.toolkit.fluxcd.io`) CRDs, `GitRepository`/
> `OCIRepository`/`HelmRepository` sources, and a per-cluster layout
> (`clusters/<env>/`, `<env>/<cluster>/`, or similar). Treat it as Flux GitOps,
> not raw manifests.

## Slice axis: **environment (PRIMARY)**

The dominant axis is the environment/cluster: `staging`, `production`, and any
special clusters (e.g. an `es-cluster`). Everything else (apps, infra controllers,
sources) is described **per environment** and, crucially, **by how the environments
differ**. The reader's top question is "what's different between staging and
production, and how does a change get promoted?"

## Phase 1 inventory (before the STOP)

- **Repo layout**: how it's organized — commonly `clusters/<env>/` or
  `<env>/<cluster>/` (the per-cluster entry Kustomizations), plus shared `apps/`,
  `infrastructure/`, `base/` + overlays. Don't assume a fixed layout — find the
  per-cluster entry point. Identify the **base vs overlay** pattern and what each
  env overlays.
- **Flux bootstrap**: `flux-system/` (gotk-components + the sync `GitRepository` and
  root `Kustomization`) — the entry point Flux reconciles from for each cluster.
- **Sources**: every `GitRepository`/`OCIRepository`/`HelmRepository`/`Bucket` and
  what it points at (branch/tag/semver range, interval).
- **Kustomizations**: the `Kustomization` CRDs, their `path`, `dependsOn` ordering,
  `prune`, `interval`, and target namespace. Build the **dependsOn dependency graph**.
- **HelmReleases**: each `HelmRelease`, its chart/source/version, and its `values`
  **per environment** (the diffs are the story).
- **Per-environment diffs**: replica counts, resource limits, image tags/versions,
  hostnames/ingress, feature flags, enabled/disabled components — staging vs prod.
- **Promotion path**: how a change moves staging → production (image automation,
  separate paths/branches, PR-based promotion, version bumps). Look for Flux image
  automation (`ImageRepository`/`ImagePolicy`/`ImageUpdateAutomation`).
- **Secrets**: SOPS/sealed-secrets/external-secrets usage; flag anything plaintext.
- **Security smells** (see checklist).

Present the inventory (environments, app/controller list, dependsOn graph,
promotion path, security findings, diagram set) and STOP. At this point, **offer**
optional live-read mode (below) — but default to files-only unless the user opts in.

## Live-read mode (optional, opt-in — see SKILL.md for the global contract)

By default, derive everything from the committed manifests/overlays; live cluster
state (actual reconciliation status, running images, drift) is tagged `VERIFY`.
**Only if the user explicitly opts in for this run** ("run in live mode" / "you can
use the cluster"), you may run **read-only** `kubectl`/`flux` introspection. Offer it
like: *"I can also read the live cluster to confirm what's actually reconciled and
running — that needs VPN connected and the right kube context selected. Want me to,
or stay files-only?"*

- **Prerequisites to state up front:** VPN connected, and the correct **kube context**
  selected for the environment you want to inspect.
- **Allowed (read-only) only:** `kubectl get/describe/logs/top`,
  `flux get/tree/stats/trace/diff`, `git log/status/show`.
- **Forbidden — never run:** `kubectl apply/create/delete/patch/edit/scale/exec/
  port-forward` (or any mutating verb), `flux reconcile/suspend/resume/bootstrap`,
  any `git commit/push/checkout/clean`.
- **Never reveal secret VALUES:** no `kubectl get secret -o yaml|json` and no
  `kubectl describe secret` that dumps data — read **existence + metadata only**
  (`kubectl get secret` names, types, `kubectl get externalsecret/sealedsecret`).
  Record *that* a secret exists and *where* it's referenced — never its decoded
  plaintext, and never write a secret value into either deliverable.
- **Confirm the target BEFORE any cluster command (critical):** print the active
  kube **context + namespace** (`kubectl config current-context`,
  `kubectl config view --minify`) and confirm with the user it's the intended
  environment — so production is never hit by accident. Re-confirm if you switch
  what you're inspecting.
- **Fail-stop:** if a command fails on access (no/wrong context, not authenticated,
  VPN down), STOP and tell the user exactly what to connect/select — don't retry
  blindly or silently fall back to guessing.
- Anything still unreadable stays `VERIFY`. Live mode reads only; it never mutates
  the cluster or the repo.

## `SYSTEM_FLOW.md` structure

1. **Overview** — what this repo deploys, to which clusters/environments, via Flux;
   the GitOps model in one paragraph (Git is source of truth; Flux reconciles).
2. **Reconciliation flow** — how a `git push` becomes running workloads: source-
   controller pulls Git → kustomize-controller builds/applies Kustomizations →
   helm-controller reconciles HelmReleases → cluster converges. A `sequenceDiagram`
   (Developer → Git → source-controller → kustomize/helm-controller → cluster).
3. **Repo layout & the base/overlay model** — a `flowchart TD` of the directory
   structure and how `clusters/<env>/` entry points pull in shared apps/infra with
   per-env overlays.
4. **Environments** — a table of clusters/environments and their purpose; the entry
   Kustomization for each.
5. **Per-environment differences** — **the centerpiece**: a side-by-side table
   (staging vs production vs …) of image tags/versions, replicas, resources,
   hostnames, enabled components, and notable values. Cite the overlay files.
6. **Promotion path** — how changes flow staging → production (a `flowchart`):
   PR/branch model and/or image automation. State the actual mechanism; `VERIFY` if
   unclear.
7. **Dependency & ordering graph** — a `flowchart` of `Kustomization.dependsOn`
   (e.g. infra/CRDs before apps) and Helm dependencies.
8. **Sources & versions** — table of every source (repo/chart) with ref/version and
   sync interval.
9. **Apps & infrastructure inventory** — per environment, the HelmReleases/apps and
   infra controllers deployed (ingress, cert-manager, monitoring, etc.).
10. **Security & tech debt** — the do-not-carry-over list (see checklist).
11. **Open questions / VERIFY list**.

## Security checklist (surface these explicitly)
Cite the manifest and say which environment(s) it affects:
- **Plaintext secrets** in Git (un-encrypted `Secret`s, tokens in values) — vs
  SOPS/sealed-secrets/external-secrets.
- **Over-broad RBAC** — `ClusterRole`/bindings with `*` verbs/resources, wide
  ServiceAccount permissions, `cluster-admin` bindings.
- **Permissive network** — missing/absent `NetworkPolicy`, `LoadBalancer`/NodePort
  exposing internal services, ingress without TLS or auth.
- **Privileged workloads** — `privileged: true`, `hostNetwork`/`hostPath`, running
  as root, missing securityContext, no resource limits.
- **Image hygiene** — `:latest` tags, unpinned charts, public/untrusted registries.
- **Reconciliation risk** — `prune: false` masking drift, no health checks,
  unbounded intervals.

## Diagrams to produce (minimum)
- 1 reconciliation `sequenceDiagram` (git → controllers → cluster).
- 1 repo-layout / base-overlay `flowchart TD`.
- 1 `Kustomization.dependsOn` ordering `flowchart`.
- 1 promotion-path `flowchart` (staging → production).
- Per-environment diff table (the must-have artifact).

## Grounding reminders — cite `path:line` for every specific value

YAML manifests are fully line-addressable. Every concrete value — image tag, chart
version, hostname, replica count, resource limit, interval, branch ref, semver
range — lives on a specific line. **Cite `path:line` for all of them.** This is not
optional; it's what distinguishes a grounded document from a summary.

Specifically:

**Per-environment diff table (§5)** — every cell that differs between environments
must cite the file and line where that value is set. Example:

| Dimension | staging | production |
|---|---|---|
| myapp image | `ghcr.io/example-org/stg-myapp` (`clusters/staging/myapp/image-automation.yaml:31`) | `ghcr.io/example-org/myapp` (`clusters/production/myapp/image-automation.yaml:33`) |
| ingress host | `myapp.staging.example.com` (`clusters/staging/myapp/ingress.yaml:14`) | `myapp.example.com` (`clusters/production/myapp/ingress.yaml:14`) |

Do NOT write a diff table row without citing the line for each env's value.

**Flux Kustomization CRDs (§7)** — for each `dependsOn` edge (or its confirmed
absence), cite the `spec.dependsOn` field location. If there are no `dependsOn`
fields, state that explicitly with a citation confirming absence (e.g. grep result
or the field simply not present in `clusters/*/flux-system/gotk-sync.yaml`).

**HelmRelease versions (§8)** — every chart version / semver range cites the
`spec.chart.spec.version` line. Every source ref (branch/tag/digest) cites the
`spec.ref.*` line in the `GitRepository`/`HelmRepository`.

**ImageUpdateAutomation / ImagePolicy (§6)** — the tag filter pattern, interval,
image repo URL, and push branch each cite their line in the manifest.

**Sources table (§8)** — every `url`, `ref`, and `interval` entry cites `path:line`.

**Security findings (§10)** — each finding (`:latest` tag, privileged container,
wildcard ClusterRole, missing NetworkPolicy) cites the exact line of the offending
field, e.g. `clusters/staging/myapp/deployment.yaml:20` not just the file.

**The bar:** a reader should be able to open any cited file, jump to the cited line,
and see exactly the value the document claims. If you can't cite a line, you haven't
read the file — tag it `VERIFY` instead.

- Read the actual overlay/patch files to state per-env differences — don't assume
  prod mirrors staging. The diffs are the highest-value content here.
- `dependsOn` and Helm `dependsOn`/`needs` give the real ordering — build the graph
  from them, citing each with `path:line` of the `dependsOn:` field.
- If the promotion mechanism isn't evident in the repo (e.g. handled by an external
  CI system), say so and tag `VERIFY` rather than inventing it.
