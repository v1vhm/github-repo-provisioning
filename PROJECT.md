# 1) Project quick facts (for grounding)

* **Goal:** create new repos from a Cookiecutter template *and* apply an initial GitHub configuration via Terraform, driven by a YAML config that lives in the template repo (separate from the cookiecutter files).
* **Where code lives:**

  * Provisioning repo: `v1vhm/github-repo-provisioning`
  * Template repo: `v1vhm/template-terraform-service`
* **When config applies:** once, during provisioning (“Configure Repository” step). No long‑term TF state tracking.

# 2) Canonical directory & file layout (paths are contracts)

* **Template repo (`v1vhm/template-terraform-service`):**

  * `cookiecutter/` … cookiecutter template content
  * `.provisioning/`

    * `repository-config.yml`  ← **authoritative repo config**
    * `README.md`              ← how to edit/test config
* **Provisioning repo (`v1vhm/github-repo-provisioning`):**

  * `modules/github-initial-config/` ← **TF module implementing config**

    * `main.tf`, `variables.tf`, `outputs.tf`, `helpers.tf` (optional)
  * `.github/workflows/create-repository.yml` ← adds “Configure Repository” job/step

# 3) Machine‑readable schema (authoritative)

**YAML schema for `.provisioning/repository-config.yml`**
(Keep it stable. Agents should validate against this.)

```yaml
# versioned for evolution
version: 1

repository:
  topics:            # optional
    - string
  visibility:        # optional: public|private|internal
  description:       # optional string

rulesets:            # optional list -> github_repository_ruleset
  - name: string
    target: "branch" # (current scope)
    enforcement: "active" | "evaluate" | "disabled"
    conditions:
      ref_name:
        include: [string] # e.g. "~DEFAULT_BRANCH"
        exclude: [string]
    rules:
      - type: "deletion" | "non_fast_forward" | "pull_request" | "code_scanning" | "required_status_checks"
        parameters:        # shape depends on type
          required_approving_review_count: int
          dismiss_stale_reviews_on_push: bool
          require_code_owner_review: bool
          require_last_push_approval: bool
          required_review_thread_resolution: bool
          code_scanning_tools:
            - tool: "CodeQL"
          required_status_checks:
            - context: string
          strict_required_status_checks_policy: bool
          do_not_enforce_on_create: bool
          allowed_merge_methods: ["merge","squash","rebase"]

labels:              # -> github_issue_label
  - name: string
    color: string        # hex (no #)
    description: string

teams:               # -> github_team_repository
  - team: string         # slug
    permission: "pull" | "push" | "maintain" | "triage" | "admin"

variables:           # -> github_actions_repository_variable
  - name: string
    value: string

secrets:             # -> github_actions_secret (value supplied by workflow env)
  - name: string
    source: "workflow_secret" | "env" | "none"
    ref: string           # e.g. "MY_ORG_SECRET_NAME" when source != none
```

# 4) Golden example config (ready to paste)

```yaml
version: 1
repository:
  topics: ["terraform","service","platform"]
  description: "Terraform-based service scaffold"
rulesets:
  - name: "trunk-based-for-terraform"
    target: "branch"
    enforcement: "active"
    conditions:
      ref_name:
        include: ["~DEFAULT_BRANCH"]
        exclude: []
    rules:
      - type: "deletion"
      - type: "non_fast_forward"
      - type: "pull_request"
        parameters:
          required_approving_review_count: 1
          dismiss_stale_reviews_on_push: true
          require_code_owner_review: true
          require_last_push_approval: true
          required_review_thread_resolution: true
          allowed_merge_methods: ["merge","squash","rebase"]
      - type: "code_scanning"
        parameters:
          code_scanning_tools:
            - tool: "CodeQL"
      - type: "required_status_checks"
        parameters:
          strict_required_status_checks_policy: true
          do_not_enforce_on_create: true
          required_status_checks:
            - context: "tf-plan-summary"
labels:
  - name: "bug"
    color: "d73a4a"
    description: "Bug or defect"
  - name: "enhancement"
    color: "a2eeef"
    description: "New feature or request"
teams:
  - team: "developers"
    permission: "push"
variables:
  - name: "ENVIRONMENT"
    value: "dev"
secrets:
  - name: "CLOUD_KV_URI"
    source: "workflow_secret"
    ref: "ORG_CLOUD_KV_URI"
```

# 5) Terraform module contract (for the agent)

**Module path:** `modules/github-initial-config`
**Purpose:** stateless, one‑shot application of config.

```hcl
// variables.tf
variable "owner"            { type = string }   // org
variable "repo"             { type = string }   // repository name
variable "config"           { type = any }      // parsed YAML (map)
variable "apply_rulesets"   { type = bool, default = true }
variable "apply_labels"     { type = bool, default = true }
variable "apply_teams"      { type = bool, default = true }
variable "apply_variables"  { type = bool, default = true }
variable "apply_secrets"    { type = bool, default = true }

// For secrets whose values come from the workflow at apply time:
variable "secret_values" {
  type = map(string)
  default = {}
}
```

**Implementation notes for the module (non‑negotiables):**

* Use `for_each` to materialize resources from lists in `var.config`.
* **Rulesets:** map YAML to `github_repository_ruleset` with nested `conditions` and `rules`. Support types shown in schema.
* **Labels:** `github_issue_label` with `repository = var.repo`.
* **Teams:** `github_team_repository` requires **team\_id**; look up with `data.github_team` by slug.
* **Variables:** `github_actions_repository_variable`.
* **Secrets:** `github_actions_secret`, values pulled from `var.secret_values` by name; skip if not present.
* **Ephemeral state:** module used in a dedicated TF working dir; no remote backend. The workflow deletes `.terraform` and `terraform.tfstate*` after apply.

# 6) Workflow step spec (deterministic sequence)

**File:** `.github/workflows/create-repository.yml` (provisioning repo)

**New block (pseudocode YAML):**

1. **Checkout provisioning repo**
2. **Checkout template repo** (to access `.provisioning/repository-config.yml`)
3. **Parse YAML** to JSON (e.g., `yq -o=json`)
4. **Write a minimal TF runner dir** with:

   * `main.tf` that:

     * configures `integrations/github` provider using the existing GitHub App token in the job
     * calls `module "initial_config"` with `owner`, `repo`, `config`, and `secret_values`
5. **terraform init / apply** with `-auto-approve`
6. **Cleanup**: remove local state files

**Required env/permissions:**

* GitHub App token with admin on target repo (already present in your flow).
* If secrets are referenced: pass them in `secret_values` from workflow secrets.

# 7) Cookiecutter variables (fixed list for this template)

* `port_service_name`
* `port_service_identifier`
* `port_repository_identifier`
* `port_cost_centre`
* `port_owning_team`
* `port_owning_team_identifier`
* `repo_name` (slug)
* (plus any existing vars your template already uses)

# 8) Agent task cards (copy/paste to run work)

**Task A — Add config scaffold to template repo**

* Inputs: repo path `v1vhm/template-terraform-service`
* Steps:

  1. Create `.provisioning/repository-config.yml` from “Golden example”.
  2. Create `.provisioning/README.md` documenting schema, examples, and how provisioning consumes it.
* Output: PR with files, passing schema lint (optional).

**Task B — Implement TF module in provisioning repo**

* Inputs: path `v1vhm/github-repo-provisioning/modules/github-initial-config`
* Steps:

  1. Create `variables.tf`, `main.tf`, `outputs.tf`.
  2. Implement resources per schema.
  3. Add `data "github_team"` lookups by slug.
  4. Add conditional creation per `apply_*` flags.
* Output: module compiles (`terraform validate` clean).

**Task C — Wire workflow step**

* Inputs: `.github/workflows/create-repository.yml`
* Steps:

  1. After cookiecutter scaffold & initial push, add “Configure Repository” job steps (Section 6).
  2. Read config from template repo checkout.
  3. Pass `owner`, `repo` and parsed `config` to module.
  4. Map workflow secrets into `secret_values` as needed.
  5. Ensure mock/dry‑run guard respects existing `inputs.mock`.
* Output: workflow runs green in a dry‑run; state files deleted.

**Task D — Cookiecutter vars**

* Inputs: template cookiecutter files.
* Steps:

  1. Ensure variables listed in Section 7 are defined in `cookiecutter.json`.
  2. Thread into README or metadata files as needed (no hard dependencies for provisioning).
* Output: cookiecutter generation works with `--no-input` and extra‑context.

**Task E — Tests & fixtures**

* Steps:

  1. Add a tiny harness (script) that validates `repository-config.yml` against the schema (optional: `pykwalify` or JSON Schema via `yaml -> json`).
  2. Add a “dry” GitHub Actions workflow job that parses the YAML and prints the derived TF plan (no apply) for PR preview.
* Output: contributors see config diffs reflected in plan.

# 9) Guardrails & invariants (the model must obey)

* **Single source of truth** for initial settings: `.provisioning/repository-config.yml`.
* **Stateless apply:** never commit or upload TF state for this step; delete local state post‑apply.
* **Idempotent:** repeated runs should converge, not duplicate resources.
* **Fail loud on schema mismatch** with actionable error text.
* **No secrets in the template repo.** Values only injected via workflow at apply time.

# 10) Acceptance criteria (checklist)

* New repo created from template gets:

  * topics/description set (if provided)
  * ruleset applied matching the JSON you supplied (deletion, non‑fast‑forward, PR reviews, CodeQL, required checks)
  * default labels/teams created
  * variables and any mapped secrets present
* Cookiecutter generation works unattended with provided context.
* Workflow cleans up TF state artifacts.
* Updating YAML in template affects **future** repos only (documented clearly).

