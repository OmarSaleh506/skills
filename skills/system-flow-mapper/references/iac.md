# Playbook: Generic Infrastructure as Code

For IaC that isn't Pulumi or Flux: **Terraform/OpenTofu**, **CloudFormation/CDK**,
**Serverless Framework / SAM**, or **standalone Helm charts / raw Kubernetes
manifests**. (Pulumi → `pulumi.md`; Flux GitOps → `flux.md`.) The shape is the same
as those: map what gets provisioned, how the pieces depend on each other, how
environments differ, and the security posture.

## Slice axis: **environment + component**

- **Environments**: Terraform workspaces / tfvars files / per-env directories;
  CloudFormation stacks/parameter sets; serverless `--stage`s; Helm values files.
- **Components**: Terraform modules; CFN nested stacks/logical groupings; serverless
  functions+events; Helm subcharts/templates.

## Phase 1 inventory (before the STOP)

- **Tool & layout**: which IaC tool; the entry (`main.tf`/root module, the CFN
  template, `serverless.yml`, `Chart.yaml`); module/stack structure.
- **Environments**: tfvars/workspaces/parameter files/values files and how they
  differ.
- **Resource inventory**: what each module/template provisions.
- **Dependency graph**: module inputs/outputs, `depends_on`, CFN `Ref`/`GetAtt`,
  resource references — the real wiring.
- **Variables & secrets**: inputs, defaults, and which carry sensitive values; the
  state backend (Terraform) and its locking/encryption.
- **Providers & regions/accounts**.
- **Pipeline**: how it's applied (CI/CD, plan/apply approval, drift detection).
- **Security smells** (checklist below).

Present the inventory (environments, components, dependency graph, security
findings, diagram set) and STOP. At this point, **offer** optional live-read mode
(below) — but default to files-only unless the user opts in.

## Live-read mode (optional, opt-in — see SKILL.md for the global contract)

By default, derive everything from committed files; live/applied state is tagged
`VERIFY`. **Only if the user explicitly opts in for this run**, you may run
**read-only** introspection to confirm deployed state. State the prerequisites
(provider auth/credentials, the right account/region/workspace selected, remote
state access) up front and offer it; never assume it.

- **Allowed (read-only) only:** `terraform show`, `terraform state list`,
  `terraform output`, `terraform plan` (diff only), `terraform validate`; cloud
  read-only CLIs (`aws ... describe/list/get`, `gcloud ... describe/list`,
  `az ... show/list`); `git log/status/show`.
- **Forbidden — never run:** `terraform apply/destroy/import/taint/state mv|rm|push`,
  any cloud CLI mutation (`create/delete/update/put/run/...`), or
  `git commit/push/checkout/clean`.
- **Never reveal secret VALUES:** don't fetch decrypted secrets — no
  `aws secretsmanager get-secret-value`, `aws ssm get-parameter --with-decryption`,
  `gcloud secrets versions access`, `az keyvault secret show`, and don't dump
  sensitive Terraform outputs/state values. Record *that* a secret exists and *where*
  it's referenced — never its plaintext, and never write a secret value into either
  deliverable.
- **Confirm the target:** before any read, print the active workspace/account/region
  and confirm it's the intended environment — never touch prod by accident.
- **Fail-stop:** if it fails on access (not authed, wrong account, locked/missing
  state), STOP and tell the user exactly what to set up — don't retry blindly.
- Anything still unreadable stays `VERIFY`. Live mode reads only; it never mutates
  state or the repo.

## `SYSTEM_FLOW.md` structure

1. **Overview** — what the infra is, the tool, provider(s), and the environments.
2. **Environments** — table of environments and their key differences (region,
   sizing, counts, flags). Cite the tfvars/parameter/values files.
3. **Module / stack architecture** — each module/template: what it provisions, its
   inputs/outputs. A `flowchart TD` of the structure.
4. **Resource dependency graph** — a `flowchart`/`graph LR` of the actual wiring
   (module outputs → inputs, `depends_on`, `Ref`/`GetAtt`). Cite the references.
5. **Network & data flow** — VPC/subnets/security groups/ingress/egress and how data
   moves; a `flowchart` if non-trivial.
6. **Variables, secrets & state** — inputs table, sensitive values, the state
   backend and its protection.
7. **Deploy / pipeline flow** — plan→approve→apply path; a `flowchart`/
   `sequenceDiagram`.
8. **Provisioned-resource inventory** — per module/stack, concrete resources (cite
   the defining file/line).
9. **Security & tech debt** — the do-not-carry-over list (see checklist).
10. **Open questions / VERIFY list**.

## Security checklist (surface these explicitly)
Cite the resource and the environment(s) affected:
- **Public storage** — public S3/GCS/Azure blobs, public ACLs/policies.
- **Open ingress** — `0.0.0.0/0` on sensitive ports; wide-open SGs/firewall rules/NSGs.
- **Over-broad IAM/RBAC** — `"*"` actions/resources, admin-equivalent roles.
- **Hardcoded secrets** — literals in `.tf`/templates/values or committed tfvars.
- **Missing encryption** — at rest (volumes/buckets/DBs) and in transit (no TLS).
- **State exposure** — unencrypted/unlocked/public remote state.
- **Other** — public IPs on internal resources, no deletion protection, logging off,
  permissive CORS.

## Diagrams to produce (minimum)
- 1 module/stack structure `flowchart TD`.
- 1 resource dependency graph (actual wiring).
- 1 deploy/pipeline `flowchart` or `sequenceDiagram`.
- Network/data-flow `flowchart` if there's a meaningful topology.
- Per-environment diff table.

## Grounding reminders
- Build the dependency graph from real references (`module.x.output`, `depends_on`,
  `Ref`/`GetAtt`), not a generic architecture template. Cite each edge.
- Per-env differences come from tfvars/parameters/values files — read them.
- Code shows the *declared* desired state, not the *deployed* state — tag any
  deployment-state claim `VERIFY`.
