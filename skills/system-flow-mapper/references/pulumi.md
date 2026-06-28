# Playbook: Pulumi (Infrastructure as Code)

For infrastructure defined as a **Pulumi program** (TypeScript/Python/Go/C#). Unlike
a backend, a Pulumi program is *imperative code that declares cloud resources* — the
map you produce is the **resource graph the program builds**, the **stacks**
(environments) it builds it for, and the **security posture** of what gets
provisioned.

> Phase-0 caution: a Pulumi-in-TypeScript repo has `package.json` + `.ts` files and
> will *look* like a Node backend. It is **not**. The tells: `Pulumi.yaml`,
> `Pulumi.<stack>.yaml`, and `@pulumi/*` dependencies. Route here, not to backend.

## Slice axis: **environment (stack) + component**

Two interacting axes:
- **Stacks** = environments/instances (`dev`, `staging`, `production`, or per-tenant
  stacks). Each has its own `Pulumi.<stack>.yaml` config and its own deployed copy.
- **Components** = the logical building blocks the program defines (often
  `ComponentResource` subclasses: network, database, cluster, service, DNS, etc.).

Map the components once, then show how the stacks differ in config.

## Phase 1 inventory (before the STOP)

- **Project & stacks**: `Pulumi.yaml` (project name, runtime), and every
  `Pulumi.<stack>.yaml` (the environments/tenants). Note multi-project layouts
  (several `Pulumi.yaml` under subdirs) — each is its own program.
- **Entry & resource graph**: the program entry (`index.ts`/`__main__.py`/etc.) and
  the resources it instantiates. Identify `ComponentResource` subclasses and what
  each wraps. Build the **dependency graph**: which resources take others as inputs
  (`.id`, `.arn`, `parent:`, `dependsOn:`).
- **Config & secrets**: per-stack config keys (`pulumi config`), which are
  `secret:`-encrypted, and where config is read in code (`new pulumi.Config()`).
- **Cross-stack references**: `StackReference` usage — which stacks consume another
  stack's outputs.
- **Stack outputs**: the `export`ed outputs and what consumes them.
- **Providers & regions**: provider(s) and explicit provider/region/account config.
- **What gets provisioned**: the concrete resource inventory per component (buckets,
  DBs, clusters, roles, networks, DNS, …).
- **Security smells** (see checklist below).

Present the inventory (stacks, components, dependency-graph sketch, security
findings, diagram set) and STOP. At this point, **offer** optional live-read mode
(below) — but default to files-only unless the user opts in.

## Live-read mode (optional, opt-in — see SKILL.md for the global contract)

By default, derive everything from committed files (the program code +
`Pulumi.<stack>.yaml`); live deployment state is tagged `VERIFY`. **Only if the user
explicitly opts in for this run**, you may run **read-only** Pulumi introspection to
confirm what's actually deployed. Offer it like: *"I can also read live stack state
to confirm deployed config/outputs — that needs `PULUMI_CONFIG_PASSPHRASE` (or a
backend login) exported. Want me to, or stay files-only?"*

- **Prerequisites to state up front:** `PULUMI_CONFIG_PASSPHRASE` exported (or
  `pulumi login` to the state backend) to read encrypted config/state.
- **Allowed (read-only, non-secret) only:** `pulumi stack`, `pulumi stack output`
  (WITHOUT `--show-secrets`), `pulumi config` (read, WITHOUT `--show-secrets`),
  `pulumi preview` (diff only), `git log/status/show`.
- **Forbidden — never run:** `pulumi up`, `pulumi destroy`, `pulumi import`,
  `pulumi config set`, `pulumi state *`, `pulumi cancel`, or any
  `git commit/push/checkout/clean`.
- **Never reveal secret VALUES:** no `pulumi config --show-secrets`, no
  `pulumi stack output --show-secrets`, no `pulumi stack export` of secret material.
  Record *that* a config value is secret and *where* it's used — never its plaintext,
  and never write a secret value into either deliverable.
- **Confirm the target:** before reading a stack, print which stack is selected and
  confirm it's the intended one (don't read/operate on prod by accident).
- **Fail-stop:** if it fails on access (no passphrase, not logged in, wrong stack),
  STOP and tell the user exactly what to export/select — don't retry blindly.
- Anything still unreadable stays `VERIFY`. Live mode reads only; it never mutates
  state or the repo.

## `SYSTEM_FLOW.md` structure

1. **Overview** — what this infrastructure is, the cloud provider(s), the Pulumi
   project(s) and runtime, and the list of stacks/environments.
2. **Stacks & environments** — a table of stacks with their purpose and key config
   differences (region, sizing, feature flags, account). This is central — readers
   want to know how prod differs from staging.
3. **Component architecture** — each `ComponentResource`/logical module: what it
   provisions and its inputs/outputs. A `flowchart TD` of the component/stack
   structure.
4. **Resource dependency graph** — a `flowchart` (or `graph LR`) showing how
   resources wire together (network → cluster → service → DNS, etc.). This must
   reflect the **actual** wiring read from the code, not a generic template.
5. **Configuration & secrets** — per-stack config table; which values are secret;
   where they're consumed. Flag plaintext sensitive config.
6. **Cross-stack references** — diagram/table of `StackReference` edges if present.
7. **Network & data flow** — VPC/subnets/security-groups/ingress and how traffic and
   data move; a `flowchart` if non-trivial.
8. **Deploy / pipeline flow** — how `pulumi up` runs (CI/CD, who applies, approval
   gates, state backend). A `sequenceDiagram` or `flowchart` of the deploy path.
9. **Provisioned-resource inventory** — per component/stack, the concrete resources
   created (cite the file/line that creates each class).
10. **Security & tech debt** — the do-not-carry-over list (see checklist).
11. **Open questions / VERIFY list**.

## Security checklist (surface these explicitly)
For every finding, cite the resource definition and say which stack(s) it affects:
- **Public buckets/objects** — `publicReadAccess`, public ACLs, bucket policies with
  `Principal: "*"`.
- **Open security groups / ingress** — `0.0.0.0/0` on sensitive ports (22, 3389, DB
  ports), wide-open NSGs/firewall rules.
- **Over-broad IAM / RBAC** — `"*"` actions/resources, `AdministratorAccess`,
  wildcard role bindings.
- **Hardcoded secrets** — credentials/keys/tokens literal in code or in non-secret
  config.
- **Missing encryption** — at rest (unencrypted volumes/buckets/DBs) and in transit
  (no TLS, plaintext listeners).
- **Other** — public IPs on internal resources, no deletion protection on stateful
  resources, overly permissive CORS, logging/audit disabled.

## Diagrams to produce (minimum)
- 1 component/stack structure `flowchart TD`.
- 1 **resource dependency graph** (the actual wiring).
- 1 per-stack config-diff view (table is fine; diagram if it clarifies).
- 1 deploy/pipeline `flowchart` or `sequenceDiagram`.
- Network/data-flow `flowchart` if there's a meaningful network topology.

## Grounding reminders
- The dependency graph must come from reading the code's resource inputs/`dependsOn`/
  `parent`, not a generic cloud-architecture template. Cite the instantiation sites.
- Per-stack differences come from the `Pulumi.<stack>.yaml` files and `config.require`
  call sites — read them; don't assume prod==staging.
- Distinguish what the program *declares* from what's *currently deployed* (you can
  only see the former from code) — tag deployment-state claims `VERIFY`.
