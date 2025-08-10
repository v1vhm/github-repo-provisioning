# Design for Automated GitHub Repository Management with Port Integration

## Overview

This repository will serve as an automation hub to **create and manage GitHub organizational resources (repositories, teams, etc.)** based on triggers from **Port**. Port is an internal developer portal (or catalog) that will invoke GitHub Actions workflows in this repo to provision and configure resources, then record their details back into Port. All changes follow a GitOps approach: the state of GitHub resources will be represented in YAML files stored in this repository (one file per entity), which are automatically updated by the workflows. The repository will be **trunk-based** (no PRs); only the automation (acting as a bot) will push commits to the default branch. This ensures a clear audited history of changes and that manual intervention is minimized.

**Key technologies:** We will use **Terraform** (with the official GitHub provider) for most provisioning tasks, leveraging its state management and consistency. Where Terraform lacks coverage of certain GitHub features, we will supplement with scripting or the GitHub CLI (`gh`) to fill the gaps. A GitHub App (with appropriate org permissions) will be used by the workflows to authenticate and perform actions across the organization, and Port’s API credentials will be stored as secrets for updating the Port catalog.

## Repository Structure

The repository will be organized for clarity and to logically separate different entity types. Key structural points:

* **Directories per Entity Type:** Each type of managed entity (e.g., **repositories**, **teams**, **environments**) will have its own directory. For example:

  * `/repositories/` – contains Terraform code and YAML state files for GitHub repositories.
  * `/teams/` – contains Terraform code and YAML files for GitHub teams.
  * `/environments/` – contains configuration (placeholder for future, e.g. deployment environments within repos).

  Within each directory, **YAML files** will represent individual instances. For example, after creating a team, a file `/teams/<team-name>.yaml` will be added to describe that team (its ID, members, etc.), and similarly `/repositories/<repo-name>.yaml` for a repository’s details. These YAML files serve as the GitOps record of the current state of each resource. They will be created and updated by the workflows (not by humans), providing an audit trail and easy review of all org resources in one place.

* **Terraform Configuration:** Each entity directory will also contain Terraform configuration for managing that entity type. We will define Terraform modules or configurations scoped to one entity at a time. For example, under `/repositories/`, there could be a Terraform module (`repo.tf` or `main.tf` plus variables) that knows how to create or update a GitHub repository (with required settings, team access, etc.). Likewise, `/teams/` will have Terraform code for team creation and membership management. Variables will be used so that the workflows can pass in specifics (like repository name, team name, etc.) when running Terraform. This layout keeps the Terraform logic for each entity type isolated and easier to manage (one directory per entity type as confirmed).

* **GitHub Workflows:** All automation is driven by GitHub Actions workflows located in [`.github/workflows/`](./.github/workflows/). We will create **one workflow file per operation** (as listed in the next section) for clarity and separation of concerns. For instance, `create-repo.yml` for the “Create Repository from Template” process, `create-team.yml` for team creation, etc. Each workflow will be triggered manually via Port’s API (see **Port Integration** below) and will perform the end-to-end steps for that specific action.

* **Reusable Components:** To avoid duplicating code between workflows, we will factor common steps into **composite actions or reusable workflow segments**. These could live under [`.github/actions/`](./.github/actions/) (for composite actions) or as separate workflow files callable by others. For example, committing the YAML file to the repo or calling the Port API might be written once and reused in multiple workflows. Similarly, a Terraform apply step could be templatized. Keeping these as shared components will make the repository easier to maintain.

* **Support Scripts:** If needed, a `/scripts/` directory can house any utility scripts (shell or Python) for tasks not handled by Terraform. For example, if using the GitHub CLI or direct API calls (for features Terraform doesn’t support well), we might have a script for adding/removing a team from a repo, etc. These scripts can be invoked by the workflows. However, many tasks can also be done inline in workflow steps using `gh` or curl, so we will create scripts only as necessary.

* **AGENTS.md:** At the root, an `AGENTS.md` file will be maintained to coordinate AI-assisted development. This file will contain the project overview, design decisions, and a checklist of implementation tasks. Each time an AI agent completes a task (e.g., creating a new workflow or updating Terraform code), it should update `AGENTS.md` to reflect the new state. This ensures continuity between independent tasks and acts as a single source of context for all AI contributions.

## Workflow Execution Pattern

All workflows will follow a similar **6-step process** (with adjustments as needed per specific action). This standardized pattern ensures consistency:

1. **Trigger from Port:** Port will initiate the workflow via GitHub Actions, passing in the necessary details (likely through a `workflow_dispatch` event with a JSON payload). For example, Port can call the GitHub Actions API to dispatch a workflow, including a JSON string of context and user input. Each workflow YAML will be configured to accept this input (e.g., an input named `port_payload`). The payload will contain identifiers (like Port run ID, blueprint ID) and properties (like the desired repository or team name, etc.). The workflow’s first step will parse this JSON input (using `fromJson()` in the GitHub Actions expression syntax) to extract the needed parameters (for instance, new repo name, team name, requested settings).

2. **Validation:** The workflow performs **technical validation** on the request. This includes checking that names are unique and valid according to rules. For example, a “Create Repo” workflow might verify that no existing GitHub repo in the org has the requested name (to avoid name collisions), and that the name meets org conventions (allowed characters, length, etc.). Similarly, creating a team will check the team name isn’t taken, and an update operation will verify the target exists. Validation steps can be implemented via the GitHub CLI or API (for example, calling the GitHub API to search for a repo or team by that name) or even a Terraform dry-run. If any validation fails (e.g., name is already in use or invalid), the workflow will abort early, and report the failure back to Port (with an appropriate error message).

3. **Generate YAML Manifest:** Before making any changes, the workflow will prepare a **YAML file** that represents the new or updated entity. This YAML is essentially a declarative record of what we intend to create. For a new repository, for instance, we’ll draft a YAML with fields like repository name, description, visibility, the team(s) attached, etc. At this stage, it may not have all details (some fields will be filled after creation, like an internal ID or URL), but it will include the input parameters and baseline settings. We do *not* commit it yet; it’s kept in the workspace as an artifact to be finalized. (This YAML could be constructed using a templating step or echoed out from the inputs – since the AI can generate code, it might directly compose the YAML content in this step.)

4. **Provision the Entity:** Next, the workflow **creates or updates the actual GitHub resource** (and related config) using Terraform or other means:

   * **Terraform Apply:** Whenever possible, use Terraform to create the resource in GitHub. We will call `terraform init` and `terraform apply` within the specific entity’s directory, passing the parameters from the Port payload as Terraform variable values. For example, in a repo creation workflow, we supply the repo name, visibility, template info, etc., to a Terraform configuration that includes `resource "github_repository"` (and possibly related sub-resources). The GitHub Terraform provider will then call the GitHub API to create the repo as specified. Similarly, team creation uses `resource "github_team"` and perhaps `resource "github_team_membership"` for adding initial members. Terraform’s plan/apply ensures idempotency and handles the heavy lifting of API calls.

   * **Using GitHub CLI/API for Gaps:** Some GitHub features are not fully covered by the Terraform provider. In those cases, the workflow will execute script steps to fill in the gaps. For example, if we need to configure repository **rulesets or certain branch protection settings** not available in the provider, we can use the `gh` CLI or REST API calls in the workflow. (Notably, the Terraform GitHub provider allows specifying a path to the `gh` CLI for some operations that the API doesn’t cover, which indicates we may invoke CLI as needed for unsupported settings.) Another example is **GitHub Environments** within a repo – if Terraform lacks direct support, we will call the GitHub API to create an environment and set its parameters. All such scripting will be integrated seamlessly into this step, after the main Terraform apply or as part of the Terraform execution (e.g., using a `null_resource` with local-exec to call CLI if needed).

   * **Cookiecutter Template Initialization:** The “Create Repository from Template” workflow has an extra sub-step: populating the new repository with initial content using a **Cookiecutter template**. After Terraform creates the empty repo (or alternatively, we could use the GitHub provider’s `template` option to create from a template repo, but here we want Cookiecutter for richer templating), the workflow will run Cookiecutter to scaffold the repository’s content. We will provide the chosen Cookiecutter template (likely a Git URL) and pass in user inputs (from Port payload) to generate the codebase. This can be done by installing Cookiecutter (`pip install cookiecutter`) and running it in **non-interactive mode** with context variables, or by using a pre-built GitHub Action from the marketplace. (There is an official Port action `port-labs/cookiecutter-gha` that does this scaffolding, but we can implement it ourselves for flexibility.) The generated project files will then be pushed to the newly created repo – for example, the workflow can do a git init, add all files, and push using an authentication token. This ensures the new repository is not just empty, but initialized per the template (including a README, boilerplate code, etc.).

   * **Port Upsert:** Within the provisioning step, we also ensure the new entity is **registered/updated in Port’s catalog**. That means calling Port’s API (using the provided `PORT_CLIENT_ID` and `PORT_CLIENT_SECRET` for authentication) to upsert the entity in the appropriate **Port Blueprint**. For example, after creating a GitHub repository, we would call Port’s API to create or update a “Repository” entity in Port’s data model, including properties like its name, URL, and relations (like which team owns it). Port provides APIs to upsert entities by identifier; we will incorporate an HTTP request (likely using a small script or action) to do this. The Port **run ID** from the payload will be used to correlate or update the correct execution run in Port, and the blueprint identifiers will ensure the data lands in the right schema. *(If we used the Port-provided Cookiecutter action with `createPortEntity: true`, it would handle this upsert for repositories automatically, but in our design we handle it explicitly for all entity types for consistency.)*

   This step (4) is the heart of each workflow: if it completes successfully, the desired GitHub resource now exists (or is updated) and Port knows about it. All intermediate outputs (like the new repository’s URL or team’s ID) will be captured for use in the next step.

5. **Finalize and Commit YAML:** If provisioning is successful, the workflow updates the YAML file created in step 3 with any additional information learned during the run. For instance, for a repo, we might now fill in the repository’s GitHub ID, the HTML URL, timestamps, or any default settings that were applied. For a team, we’d record its team slug or ID and current membership list. Essentially, the YAML becomes the **source of truth snapshot** of the resource’s configuration post-creation. Once updated, the workflow will **commit this YAML file to the repository** (and possibly any other affected YAML, such as linking a team to a repo might require updating both the repo’s and team’s YAML). The commit will be made directly to the `main` branch (trunk-based flow) using the GitHub Actions bot or the Port bot identity. We’ll include an informative commit message like “Add repo `<name>` (automated)” or “Update team `<name>` members (automated)”. This commit provides traceability and ensures that the GitOps repo state now matches reality. We can perform the commit using a GitHub Action (there are marketplace actions like “Add & Commit” to simplify this) or via a git command script (the Action’s `GITHUB_TOKEN` or a dedicated bot PAT will be used to authenticate the push).

6. **Report Status to Port:** Finally, the workflow reports the outcome back to Port. Port expects a status (success/failure) for the action it triggered. We will use Port’s API (authenticated with the same client ID/secret) to send a completion status, possibly including any key outputs. For instance, if Port’s action blueprint expects the new repository’s URL or ID as an output, we include that. In Port’s terminology, when an action is triggered, the integration can call back with `runId` to mark it completed and attach output properties. This could be a simple REST call to an endpoint Port provides (using the `runId` from the initial payload to correlate) indicating success or error and any message. After this, Port’s UI/engine will know the result (so it can display to users or update its catalog entries accordingly).

Throughout the workflow, robust error handling will ensure that if any step fails (e.g., Terraform error, API call fails), the workflow catches the error, reports a failure status to Port, and does not commit any partial YAML. This keeps the GitOps state clean (only successful changes are recorded). Partial changes (if any) will be rolled back where possible or flagged for manual attention.

## Port Integration and Security

Because Port is orchestrating these workflows, we need to integrate carefully and securely:

* **Workflow Triggers:** As noted, each workflow is triggered by Port via a `workflow_dispatch` event. In Port, an Action would be defined with invocation method “GitHub” pointing to this repo and the specific workflow file. Port will send the `port_payload` input JSON containing context (the Port blueprint, run ID, etc.) and user-provided inputs (like the name of the resource to create). Our workflows will be set to `on: workflow_dispatch` with an `inputs: port_payload` schema to accept this. This means these workflows won’t run on push or schedule by themselves, only when called by Port (or manually triggered if needed for testing). We will document in Port’s configuration what JSON structure is expected, and our workflow code will parse it accordingly (as seen in the Port example, using `fromJson` to decode the payload).

* **GitHub App / Authentication:** We will create a **GitHub App** for this automation, installed on the organization, with permissions to manage repositories and teams. The workflows will use this app’s credentials to authenticate GitHub API calls (instead of a user PAT, for better security and audit). The App will need scopes such as: repository administration (to create repos, update settings), organization read/write (to create teams, manage team membership, manage org secrets if needed for environments), etc. We will store the App’s **private key** and App ID as secrets in this repo, or use an Action to generate installation tokens at runtime. For example, the workflow can use an action like `tibdex/github-app-token` (providing the app ID and key) to generate a temporary token that can be set as the `GITHUB_TOKEN` for subsequent API calls. This token would be used by Terraform (via the GitHub provider) and by any direct API/CLI calls to perform org-wide changes.

  As a fallback or for initial simplicity, we might also configure a PAT (Personal Access Token) with the necessary scopes as a secret (similar to `ORG_TOKEN` in Port’s example). This PAT would belong to a bot service account. However, using the GitHub App is preferred for tighter control. In either case, the secret (token or app key) will be referenced in the workflows so Terraform and scripts can authenticate to GitHub.

* **Port API Credentials:** Port provides a client ID and client secret for API access. These will be stored as secrets `PORT_CLIENT_ID` and `PORT_CLIENT_SECRET` in the GitHub repo (already planned by the user). The workflows will use these to call Port’s APIs. For example, when upserting an entity, we’ll likely call an endpoint like `https://api.getport.io/v1/blueprints/<BlueprintID>/entities` (exact URL to be determined from Port’s docs), including the client ID/secret in an Authorization header or to obtain a token. The JSON payload will include the properties of the entity (like name, description, links) so that Port’s catalog is updated to mirror the newly created GitHub resource. In the Port Action configuration, we might not use the `createPortEntity` auto-feature of Port’s GitHub actions, since we are handling it manually, so we ensure no duplicate entries are created.

* **Secrets Management:** All secrets (Port credentials, GitHub App credentials or PAT) will be stored in GitHub Actions secrets. They will be referenced in workflow YAML using `${{ secrets.SECRET_NAME }}` syntax. We will **not** log these or expose them. When passing secrets to Terraform, it can pick up the GitHub token via environment (the GitHub provider typically looks at `GITHUB_TOKEN` or can be configured via env vars), and Port credentials will be used in curl commands or a custom action to hit the API. The use of a GitHub App also means we might need to pass the token into Terraform – the GitHub provider can accept a token via the `GITHUB_TOKEN` env var or a provider config. We’ll ensure the token is available in the environment when running `terraform apply`.

* **Permissions:** The repository’s GitHub Actions configuration (`workflow` scope) will allow it to use the required permissions. We’ll likely need to set `permissions:` in the workflow YAML to allow `contents: write` (for committing to this repo), `issues: write` (if we want to create issues on failure, maybe not needed), etc., and ensure the GITHUB\_TOKEN has those rights. The token from the App or PAT will cover the org-level changes.

By setting up these integration points, Port can securely trigger automation and get feedback, while our workflows have the authority to make the necessary changes in GitHub.

## Terraform Implementation and State Management

Terraform will be a core component of this automation, providing a declarative way to manage GitHub resources and ensure consistency. Here’s how we will use Terraform in this project:

* **GitHub Provider:** We will use the official **integrations/github** Terraform provider (latest version). This allows managing repositories, teams, memberships, branch protections, etc., through Terraform scripts. Each workflow will initialize Terraform in the context of the relevant directory (using a specific working directory). We’ll include a Terraform configuration file in each entity directory defining the resources for that entity. For example, in `repositories/main.tf` we might have:

  ```hcl
  provider "github" {
    # (Authentication is via environment GITHUB_TOKEN provided by the GitHub App/PAT)
    owner = "<org-name>"  # set to our GitHub organization
  }

  variable "repo_name" { type = string }
  variable "visibility" { type = string }
  # ... other variables as needed (description, template, team to attach, etc.)

  resource "github_repository" "new_repo" {
    name        = var.repo_name
    visibility  = var.visibility
    description = var.description
    template {
      # If using GitHub's template repo feature (optional alternative to cookiecutter)
      owner      = var.template_owner
      repository = var.template_repo
    }
    # other settings like default_branch, features (issues/projects), etc.
  }

  # Example of attaching a team with specific permissions, if using Terraform:
  variable "team_slug" { type = string }
  variable "team_permission" { type = string }  // e.g. "push", "maintain"
  data "github_team" "team" {
    slug = var.team_slug
  }
  resource "github_team_repository" "team_access" {
    team_id    = data.github_team.team.id
    repository = github_repository.new_repo.name
    permission = var.team_permission
  }
  ```

  The above is illustrative. In practice, we will adjust depending on whether we decide to attach the team via Terraform or via the GitHub CLI. The GitHub provider covers many aspects (repos, teams, memberships, branch rules, etc.), but not everything.

* **Handling Unsupported Features:** Some GitHub features like organization-level rules, fine-grained permissions, or repo environment rules might not be supported directly. For those, we will integrate one-off solutions:

  * Use Terraform’s flexibility: We can leverage the **null\_resource** with `local-exec` to run shell commands (e.g., `gh` CLI or curl). For instance, if we want to enforce a specific branch protection rule that isn’t exposed in the provider yet, we create a null\_resource that triggers a script to call the GitHub API (ensuring it runs after the repo is created by using `depends_on`). This way, Terraform still orchestrates the sequence.
  * Use external actions: In workflows, after Terraform apply, run an Action or script to do the remaining config.

  We will document within the Terraform code where such gaps exist. For example, a comment **“GitHub Terraform provider cannot set XYZ, so we call CLI here”** and ensure those actions are only executed on create/update as needed. The use of the `GH_PATH` environment in the provider hints at one method: if placed, certain missing pieces might be auto-fulfilled by the provider via CLI calls. We’ll investigate if that covers our needs; otherwise manual scripting is our plan B.

* **Remote State Backend:** All Terraform state will be stored remotely in an **Azure Storage Account** (as per requirement). We will set up an Azure Blob container (for example, named `tfstate`) to hold the state files. Each Terraform invocation will use this backend, enabling state locking and persistence. Crucially, to **prevent the state from becoming unmanageable**, we will not use a single monolithic state file for all resources. Instead, we’ll **split state by entity**. Possible strategies include:

  * **One state per entity type**: e.g., one state file for all repositories, one for all teams. This is simpler but could still grow large if many resources accumulate. It also means concurrent changes to two different repos would lock the same state.
  * **One state per resource instance**: e.g., each repository gets its own state file, each team its own state file. This maximally isolates changes (no locking conflicts at all if different resources). The downside is potentially many small state files to manage, but Azure can handle that, and it keeps operations focused.

  We will likely adopt a middle ground or lean toward **per-resource state files** for ultimate independence. That means when creating a new repo, we initialize Terraform with a backend config pointing to a key like `"repos/<repo-name>.tfstate"`. For a team, `"teams/<team-name>.tfstate"`, etc. The workflow can inject the resource name into the backend configuration dynamically. This can be done by using Terraform CLI arguments: for example, `terraform init -backend-config="key=repos/${{ inputs.repo_name }}.tfstate"` (for Azure storage, the key is the blob name). Similarly for teams. With this approach, each Terraform run handles exactly one resource and its state is isolated.

  *Example:* If we create `awesome-app` repository, Terraform state might be stored at `tfstate/repos/awesome-app.tfstate` in Azure. If later we need to update that repo, the workflow will init with the same key to pull the existing state and perform an update. For operations linking resources (like adding a team to a repo), we might either choose one of the relevant state files or manage that without Terraform (to avoid complex coordination of multiple states, as discussed earlier).

* **State Locking and Concurrency:** Azure Blob backend supports state locking (via Azure file leases). By splitting state, we reduce the chance that two workflows contend on the same state file. However, if there were parallel runs on the *same* resource (which Port is unlikely to trigger simultaneously), the backend lock will prevent corruption. We will also implement some minimal concurrency control in workflows if needed (for example, if a repo creation and an update for the same repo launched concurrently, one should wait or fail fast). But the expectation is Port/our system will handle sequential requests per resource.

* **Terraform Workflow in Actions:** In the GitHub Actions YAML, after checkout, we will set up Terraform like:

  * Install Terraform (or use a pre-made action/setup).
  * Configure Azure credentials (likely via Azure service principal secrets or workload identity) so Terraform can access the remote backend. We’ll need environment variables for Azure storage account name, key, etc., unless the storage container is public (not recommended). Most likely we use an Azure storage access key as a secret.
  * Run `terraform init` with backend config (as mentioned) and specify the backend container, resource group, etc. This could be abstracted in a composite action since it will be similar for all workflows (just different state key).
  * Run `terraform apply -auto-approve -var='name=...' -var='others=...'`. We’ll pass all necessary variables from the Port payload into Terraform. This can be done inline or by writing a temporary `terraform.tfvars` file in the workflow. For example, the workflow might echo out a tfvars file with the content of the Port inputs (like `repo_name="my-repo"` etc.) then call Terraform.
  * Terraform will create/update the resource. We’ll capture outputs as needed. If we define outputs in Terraform (e.g., the new repository’s git URL, or team ID), the workflow can parse those (Terraform can output to JSON with `-json` flag which we can grep/jq, or we can use the `outputs.tf` to map to environment via the `terraform output` command).

* **State File Lifecycle:** Because this system aims to manage the resources long-term, we will keep state files around in Azure for reuse on updates or deletes. For deletions (like deleting a team), we will run `terraform destroy` using the same state so that it knows what to remove. After a successful destroy, we might choose to delete the state file as well (to clean up), which Azure allows by removing the blob. This will be considered to avoid ghost state files for deleted resources.

In summary, Terraform will give us a robust way to manage resources declaratively and handle dependencies (e.g., ensure a repo exists before adding a team to it, if we ever did that in one config). The multiple-state strategy isolates changes and keeps each state small. We’ll maintain a clear mapping between resource and its state file (likely documented in the YAML or as a naming convention).

## Workflows Design Details

Now, let’s outline each of the initial workflows and how they will function, following the general pattern but with specifics:

### 1. **Create Repository from Template**

**Trigger:** Invoked by Port when a new repository is requested (likely tied to a “Microservice” or similar blueprint create operation in Port). The payload will include at least the repository name, intended visibility (private/internal/public), the template to use (Cookiecutter template repo URL or an identifier), and possibly which team or owner to associate.

**Steps:**

* *Validation:* Check that the repository name is not already in use in the GitHub organization. Also validate name format (e.g., lowercase, no spaces, whatever conventions). This can be done via a GitHub API call (`gh api /repos/ORG/NAME` to see if it 404s) or using Terraform’s data source `github_repository` to attempt to find it (which should fail if not found). If the name is taken or invalid, exit with an error status to Port.
* *YAML Draft:* Create `repositories/<repo-name>.yaml` with fields like:

  ```yaml
  name: <repo-name>
  description: "<description from input or default>"
  visibility: <visibility>
  template: "<cookiecutter template used>"
  team: <team name or ID that will be given access>
  status: "creating"
  ```

  (Including a status or timestamp can be useful for debugging; we might remove or update it later.)
* *Provision:*

  * **Terraform:** Run Terraform to create the repo in GitHub. This includes settings such as visibility, description, initializing with a README (maybe), enabling issues or projects as needed. If a team is specified and we want to use Terraform for it, include the `github_team_repository` resource to attach the team with the given permission (e.g., the Port input might specify the role like admin/write). If Terraform provider supports creating from a template repository natively, we could use it, but since we have Cookiecutter, we will likely create an empty repo first. Terraform outputs we’ll capture: repository **ID** (GitHub GraphQL ID or numeric ID), and **HTML URL** (web link).
  * **Cookiecutter:** With the repo now created (but empty), run a Cookiecutter scaffold. Suppose the payload had template URL and some variables (like project name, programming language, etc.), we pass those to Cookiecutter. For instance:

    ```bash
    pip install cookiecutter
    cookiecutter --no-input -o generated/ "$TEMPLATE_URL" project_name="$repo_name" other_var="$input_other"
    ```

    This generates a new project in `generated/<repo_name>/`. We then initialize a git repo in that folder, add all files, commit, and push to GitHub:

    ```bash
    cd generated/<repo_name>
    git init
    git remote add origin https://x-access-token:$GITHUB_TOKEN@github.com/ORG/<repo_name>.git
    git checkout -b main
    git add . 
    git commit -m "Initial commit from template"
    git push origin main
    ```

    We can use the installation token from the GitHub App or the PAT to authenticate the push. After this, the new repository has all the template content. *(If using the Port Labs Cookiecutter Action instead of manual steps, it would handle repo creation, template, and commit in one step. But in our design, we split it to use Terraform for creation and manual push for content to showcase control.)*
  * **Port Upsert:** Call Port API to create a new entity in the “Repository” blueprint. Include properties like name, URL, description, etc., and relate it to the corresponding team’s entity (if a team was given as owning team, we set a relation in Port so the team blueprint entry links to this repo). This might involve an HTTP POST with a JSON body constructed from the data we have. Since Port’s client ID/secret are in secrets, we might first obtain a token if required (some Port APIs might use OAuth client credentials flow). We will incorporate this as a small step using `curl` or a GitHub Action from Port (if one exists, e.g., `port-labs/port-github-action`).
  * **Outputs:** Gather outputs for YAML: the repo’s URL (e.g., `https://github.com/ORG/NAME`), maybe an SSH URL, repository ID, etc. The Terraform output or GitHub CLI can give us that.
* *Finalize YAML:* Update the earlier YAML draft with additional info, e.g.:

  ```yaml
  id: <github-repo-id>
  url: https://github.com/ORG/<repo-name>
  created_by: <Port user or automation user who initiated>
  template_used: <template name or URL>
  team: <team-name>  # if one was attached
  ```

  Possibly also record a timestamp or a flag if the repo is currently archived or active. Mark status as "active" or remove the status field. Ensure the YAML contains everything needed to reconstruct the repo settings if needed (except secrets).
* *Commit & Push:* Use GitHub Actions to commit this new file to the repo. The commit message could be “Add repository `<repo-name>` (created via Port)”. If the repository YAML directory has an index or README, we might update that too (like a list of repos), but that’s optional. This commit is done with the bot credentials.
* *Report to Port:* Send a success callback to Port with the run ID, indicating the repo creation was successful. Possibly include the repository URL or ID in the payload so Port can store that as part of the entity’s properties (in Port’s UI, they might want to click the link to the repo). If any part failed, send a failure status with error details.

**Notes:** The workflow will likely run on `ubuntu-latest` (GitHub-hosted runner) as specified, using our GitHub App token for auth. We must ensure that the GitHub App or token has org-level permission to **create repositories** (for the specified org). We saw in the Port example that they needed a PAT with `repo` scope for this, which corresponds to our use of an App with repository management permission. Also, after repo creation, if we want to enforce certain standards (like branch protection rules, default branch naming, etc.), we can include those either via Terraform (`github_branch_protection` resource for default branch) or CLI (for rulesets). This could be added as an extension in the future. Initially, we focus on the primary tasks: create repo, set basic settings, add team, push template, record in Port.

### 2. **Create Team**

**Trigger:** Initiated from Port when a new team is requested (likely a blueprint for “Team” or part of an org structure creation). The payload will include the team name, and possibly an initial list of members (GitHub usernames) to add to the team. It might also include team parent (if we allow nested teams), or team privacy (secret vs visible).

**Steps:**

* *Validation:* Check that the team name isn’t already taken in the GitHub org. We can use the GitHub API or Terraform data source to see existing teams. Also ensure the name meets any naming policies (e.g., no spaces or special chars if we restrict that). If a parent team is specified, verify that parent exists.
* *YAML Draft:* Create `teams/<team-name>.yaml` with fields:

  ```yaml
  name: <team-name>
  description: "<optional description>"
  members: [ ]   # will fill if members provided
  parent: <parent-team-name (if any)>
  ```

  Possibly include a placeholder for team ID or slug.
* *Provision:*

  * **Terraform:** Use Terraform to create the team. The configuration would use `resource "github_team"` for the new team, including name, description, privacy (secret or closed). If a parent team is given, the provider supports that via an attribute (e.g., `parent_team_id`). We will supply that (resolving the parent’s ID via a data source if needed). Terraform output will include the new team’s **ID** and **slug** (the URL-friendly name GitHub generates, often same as name but lowercase).
  * If an initial list of members is provided, we have two approaches:
    a) **Terraform managed membership:** We can loop through the list with `resource "github_team_membership"` for each user, adding them to the team. This ensures those members are all added. However, we must be careful: if the team is new, there’s no pre-existing state, so that’s fine. If some usernames are invalid, Terraform will error; we should handle or pre-validate that (maybe check each username’s existence via GitHub API before applying).
    b) **Scripted addition:** Alternatively, add members via GitHub CLI one by one (`gh api PUT /orgs/ORG/teams/TEAM/memberships/USER`) after creating the team. But since Terraform can do it and keep track until completion, using Terraform is okay here. We’ll likely do it in Terraform for creation for completeness, then use scripts for incremental updates later.
  * **Port Upsert:** Call Port API to create a new entity in the “Team” blueprint. Include team name, description, and perhaps the list of members as a property (though in Port, one might instead model members as relations to a User entity – depends on Port’s data model; but we can at least store member count or names). If parent team exists, update the Port entity to link to the parent team’s Port entity (relation).
  * **Outputs:** Capture the team’s slug and ID from Terraform output.
* *Finalize YAML:* Update the YAML with the new info:

  ```yaml
  id: <team-id>
  slug: <team-slug>
  members:
    - user1
    - user2
  ```

  (Fill in the members list from the input, or better, from actually who was added successfully. If some additions failed, reflect that by maybe listing who is confirmed in the team via a GitHub API list-members call post-creation.) If team privacy or other settings, include those as fields. Possibly track if it’s a parent or child team.
* *Commit:* Commit `teams/<team-name>.yaml` to the repo (e.g., message “Add team `<team-name>`”).
* *Report to Port:* Send success status to Port with any relevant info (maybe team URL on GitHub, though teams have URLs like orgs/ORG/teams/slug). On failure, report error.

**Notes:** Team creation via GitHub App requires the app to have `read/write` permissions on organization teams. We should also consider that adding members might require those users to already be part of the GitHub org (if not, GitHub will error). We might need to handle that scenario – possibly Port would only allow choosing users that exist in org. If not, the workflow could attempt to invite the user to the org (if allowed) before adding to team. This could be an extension (GitHub has an invitation API). We will note this as a potential future feature. Initially, assume members are existing org members.

### 3. **Update Team**

**Trigger:** Invoked when a team’s configuration or membership needs to be updated. In Port, this could be a “Update” action on a Team entity. The payload would include the team identifier (name or an ID) and the changes to apply. Changes could be: adding or removing one or more members, changing the team’s description, or even renaming the team (though renaming a team in GitHub is effectively changing the slug and is a sensitive operation – we may or may not allow that initially).

**Steps:**

* *Validation:* Verify the team exists. If payload uses team name, ensure we can find that team. If not found, report error. If renaming is requested, check the new name isn’t taken. Validate any user names provided for addition/removal actually exist in org.
* *YAML Load:* Since this is an update, we might want to fetch the current YAML from the repo to understand the current state (or rely on GitHub as source of truth). The workflow can read the `teams/<team-name>.yaml` file (since it’s in the repo) to get the current recorded members, etc., or use GitHub API to list current members. Either way, we need the delta of what to change. Port’s payload might directly specify “add these users” or “remove these users” or a whole new list. We’ll design for a simple case: say Port provides a new full member list or a specific action type (like “AddMember” vs “RemoveMember”).
* *Provision:* For updates, using Terraform can be tricky if doing partial changes, but possible if we treat the single team’s state as authoritative:

  * **Option A: Terraform (full state):** We could pull the team’s existing Terraform state (from Azure) and update it with the new desired configuration. For example, if Port provides a full list of members that should be in the team, we update the `github_team_membership` resources (via variables). Terraform will then add any missing members and remove any extra members to match the list (ensuring the team ends up exactly as specified). This is an *idempotent* approach but requires that we have the complete desired state. If Port just said “add user X”, we’d have to construct the desired state as “previous members + X” anyway. This might be fine since we can retrieve previous members.
  * **Option B: Script incremental:** Simpler for single operations: if Port’s action is specifically to add one member or remove one member, it’s straightforward to just call the GitHub API for that change. For example, `gh api PUT /orgs/ORG/teams/TEAM/memberships/USER` to add (or invite) a user, or `DELETE /orgs/ORG/teams/TEAM/memberships/USER` to remove. This avoids Terraform overhead for a small change. For now, we assume Port might send full state (since it's a “Update team” action generally), so we can use Terraform for consistency.
  * **Terraform path:** Use the same `github_team` resource for any team property changes (like description) by setting the new values. Use multiple `github_team_membership` resources for the member list. We’ll have Terraform fetch the team by ID or name (could use `data.github_team` if needed) to ensure it’s referencing the correct team. Then apply the new configuration. Terraform will then output the updated list of members or confirmation.
  * **Port Upsert:** Update the team entity in Port via API. If membership is stored in Port, update that (or if Port instead references GitHub for membership, it may not require storing each username as a property – this depends on Port’s blueprint design, but we can send an update anyway). If team name changed, we should update the Port entity’s name too.
* *Finalize YAML:* Modify the existing YAML file for that team. Update any fields that changed (description, name, etc.). Update the members list to the new set. If the team was renamed, we might choose to rename the YAML file as well to match (which is a git operation – delete old file, add new file). That could be done in the same commit (with a note that the team was renamed). This is a bit complex, so initially we might disallow renaming via Port to avoid that scenario.
* *Commit:* Commit the updated YAML. Commit message like “Update team `<team-name>` membership” or “Update team `<team-name>` settings”.
* *Report:* Send status back to Port (success or failure with details).

**Notes:** Because this is an update on existing, we should be careful to always reference the correct team. We might rely on the team’s slug or ID internally (which we have from creation time in the YAML). Possibly the Port payload could include the team’s Port entity ID which correlates to GitHub team slug. We might use the YAML store as the source of truth for linking Port ID to GitHub team slug. AGENTS.md will contain notes on how we correlate these IDs for the AI to use when writing code.

### 4. **Update Repository**

**Trigger:** Called when a repository’s metadata or settings need to be modified (non-destructive changes). For example, updating the repo description, changing visibility (making a private repo public or vice versa, if allowed), toggling features (e.g., enable issues or wiki), or adding custom topics/labels. This would correspond to an “Update” action on a Repository entity in Port.

**Steps:**

* *Validation:* Verify the repository exists (by name). If not, error out. Check that requested changes are allowed (e.g., if making a repo public is against policy, then reject). Also ensure no conflicts (like trying to use a repo name change – we likely won’t allow name changes through this workflow; GitHub does allow renames, but it’s better handled separately due to URL changes).
* *Provision:* We will leverage Terraform to manage these settings since they map well to the `github_repository` resource attributes. Steps:

  * Pull the latest state for that repository (state file `repos/<name>.tfstate` in Azure). Run `terraform init` with that state key, and `terraform plan/apply` with new variables for the updated fields. For example, if the new description is provided, pass that in; if visibility change, set that variable. Terraform will then call GitHub API to update those fields.
  * If the update is something Terraform doesn’t cover (e.g., adding a branch protection rule, or toggling an internal setting not in provider), we use the CLI. But generally description, homepage URL, topics, visibility are supported in the provider.
  * If multiple changes are needed at once, handling them together in one Terraform apply ensures consistency.
  * **Port Upsert:** Update the repository entity in Port. E.g., if description changed, send that new description to Port. If visibility changed, update that property in Port’s record. Essentially sync Port with the new state.
* *Finalize YAML:* Open the `repositories/<repo-name>.yaml` and update the fields that changed. For example, new description text, or `visibility: public` -> `visibility: private`, etc. We might also include a `last_updated` timestamp field to track changes, but that’s optional.
* *Commit:* Commit the updated YAML file (message like “Update repo `<name>` settings”).
* *Report:* Back to Port with success or failure.

**Notes:** This workflow should avoid doing anything destructive (like removing teams or deleting the repo). It’s strictly for editable properties. If a user needed to do something like remove a team’s access or archive the repo, those are separate dedicated workflows (see below). By keeping this focused, the Terraform template for repo updates will exclude fields that we handle elsewhere to avoid accidental removal (for instance, it won’t manage team permissions in this workflow – that’s handled by the Add/Remove team workflows – so we need to be careful not to have Terraform try to reconcile team access here). We might use the Terraform `ignore_changes` feature on certain attributes in this context. Another approach is to have separate Terraform configurations for different concerns (one for core repo settings, one for relationships), but that might be overkill. Simpler is: do not include team permissions in the `update repository` TF run.

### 5. **Add Team to Repository**

**Trigger:** Called when a team needs to be granted access to a repository. In Port’s system, this might be an action on a “Repository” entity like “Add Team Access” with inputs for team name and permission, or on a “Team” entity like “Add to Repository”. We’ll design it as focusing on repository context. The payload includes repository name (or ID) and the team name (or slug) to add, plus the permission level (e.g., pull, push, maintain, admin).

**Steps:**

* *Validation:* Confirm both the repo and team exist. If either is missing, abort. Also check that the team isn’t already a collaborator on that repo with equal or higher permissions – if so, we may consider it a no-op or report that it already has access. If the team exists but with a different permission and the request is for a new permission, this essentially means updating the permission (which this workflow can handle by setting the new permission, overriding the old one). GitHub allows upgrading or downgrading team permissions easily via the same API call.
* *Provision:* For this operation, using Terraform is possible (via `github_team_repository` resource), but it introduces complexity in state (we’d have to decide where to store that state, possibly in the repository’s or team’s state). Considering this is a relatively straightforward API action, we can do it with a direct call:

  * Use GitHub CLI or API to add the team to the repo. For example, GitHub REST:
    `PUT /orgs/:org/teams/:team_slug/repos/:owner/:repo` with JSON `{"permission": "push"}` (or appropriate permission) will add or update the team’s access. The CLI `gh` has a command `gh team add <team> <org>/<repo> -r <role>` which can simplify this. We will execute one of these in a script step.
  * (If we were to use Terraform: we’d run in the repository’s TF context and add a `github_team_repository` resource then apply. This would require the repo’s state and knowledge of team ID. This is doable and ensures the link is recorded in state. However, since we plan to track the relationship in YAML and Port anyway, it might be acceptable not to have Terraform state for the link. We can rely on GitHub as source of truth for actual permission, and our YAML/Port for documentation. For simplicity, we choose the direct API method here.)
  * Confirm success of the API call (check response code 204 for success).
  * **Port Update:** In Port’s model, we should reflect this new relationship. Likely, the “Repository” blueprint has a relation to “Team” (e.g., a repository *has many* teams with access, or specifically an “owner team”). If the added team is an “owner” or primary team, we might update that field; if not, perhaps Port just catalogs it as another relation. We’ll send an update to Port for the repository entity, maybe adding an entry to a list of related teams or updating a property. Similarly, we might update the Team entity to include the repository in its relations. This depends on how Port expects to store it – if Port has the ability to handle many-to-many, we might have to create an “Access” relation blueprint. But as a simpler approach, Port could just keep a reference on the repo to teams. In any case, we will call Port’s API appropriately to register that “Team X now has access to Repo Y”.
* *YAML Update:* Edit the `repositories/<repo-name>.yaml` file to add the team in an access list. For example, we can include a section:

  ```yaml
  teams:
    - name: <team-name>
      permission: <role>
  ```

  If the `teams` list already exists in the YAML, just append or update the entry for that team. Also, it might be wise to update the `teams/<team-name>.yaml` to list the repo under a list of `repositories:` that the team has access to. However, maintaining it on both sides can cause double-edit complexity. We could choose to single-source it (perhaps only list teams under repo, and not list repos under team to avoid duplication). But for completeness, a team YAML might also list its repositories. If we do that, this workflow should update both YAML files (repo and team). We must handle the git commit of two files. We can do that in one commit easily (just ensure both changes are staged).
  We will decide to at least update the repository YAML. Optionally the team YAML too, as it could be useful to see all repos a team has in one place. Let’s assume we update both for full transparency.
* *Commit:* Commit the updated YAML file(s). Commit message like “Grant <team-name> access to <repo-name>”.
* *Report:* Notify Port of success or failure. On success, the Port run could even trigger a refresh of data or simply rely on our upsert.

**Notes:** We need the GitHub App to have permission to manage team access to repos (which it should as part of org admin or at least team and repository management permissions). The YAML consolidation of relationships should be handled carefully to avoid conflicts. Because two different workflows could conceivably update the same repo YAML (for example, adding two different teams around the same time). We may need to handle locking at the repo YAML level or just rely on sequential Port triggers. Possibly design decision: Only one team-to-repo addition should happen at once to avoid race conditions. If concurrency is a concern, we might implement a mechanism (like a queue or having Port ensure one action at a time per resource). Initially, we’ll assume sequential operations for simplicity.

### 6. **Remove Team from Repository**

**Trigger:** Called when a team’s access to a repository should be revoked. The Port action would include the repository and team identifiers.

**Steps:**

* *Validation:* Check the team indeed has access to the repository currently. If not (already removed), we might just report success or a no-op (but we should inform if it was not found). If present, continue.
* *Provision:* Use GitHub API/CLI to remove the team’s permission. REST API: `DELETE /orgs/:org/teams/:team_slug/repos/:owner/:repo`. The `gh` CLI likely has `gh team remove <team> <org>/<repo>` or similar (if not, the API call via `gh api -X DELETE` will do). After this, the team will no longer appear in the repo’s access list on GitHub.
* *Port Update:* Update Port’s records to remove that relationship. So the repository entity in Port should have team X removed from its list of related teams. Similarly, update the Team entity’s relations. We’ll call Port API to reflect this change (possibly by sending the new list of teams for the repo, or using a specific endpoint to delete the relation).
* *YAML Update:* Edit `repositories/<repo-name>.yaml` to remove the team entry from the `teams` list. Also, if we were listing repos in the team’s YAML, remove the repo from `teams/<team-name>.yaml` as well.
* *Commit:* Commit the changes (e.g., “Remove <team-name> from <repo-name> access”).
* *Report:* Send status to Port.

**Notes:** This is essentially the inverse of the Add workflow. We will ensure to handle if the team or repo doesn’t exist (error out accordingly). If the team was the primary owner of a repository (depending on how the org uses teams), removal might orphan the repo’s ownership – but that’s an org policy issue, not technical. We might consider warning or preventing removal of the last team with admin access to a repo, to avoid leaving it unowned (unless org admins are acting as owners). For now, we won’t embed that logic unless requested. Logging the event to an audit (via commit and Port) should be sufficient.

### 7. **Archive Repository**

**Trigger:** Initiated when a repository should be archived (read-only state). Port might have an action like “Archive” on a Repository entity. Inputs would be the repository name/ID (and possibly a confirmation flag).

**Steps:**

* *Validation:* Verify repo exists. Ensure it’s not already archived. Possibly check if archiving is allowed (maybe not archiving critical repos without approval, but that’s outside scope – assume Port handles approval).
* *Provision:* We can use Terraform or API for this:

  * Terraform approach: Use the `github_repository` resource’s `archived = true` attribute. By running a targeted apply that sets `archived:true` for that repo, Terraform will call the GitHub API to archive it.
  * Alternatively, a direct API: `PATCH /repos/:owner/:repo { "archived": true }`. This is straightforward and might be quicker to implement. However, since we likely have the repo’s Terraform state, using Terraform ensures if we stored other settings, they remain consistent. Either way is fine.
  * We will likely do the quick API call to archive/unarchive to avoid needing to manage state for a one-time action (plus unarchiving might not be a separate workflow yet, but we could easily do a similar approach if needed).
  * After archiving, the repository becomes read-only on GitHub.
  * **Port Update:** Update the repository entity in Port to mark it as archived (maybe a boolean property “archived: true” or status field). Port’s UI might treat archived services differently, so it’s good to flag it.
* *YAML Update:* Open `repositories/<repo-name>.yaml`, set an `archived: true` field. Possibly also note the date of archiving or by whom (the Port user). Remove or mark any other dynamic info if needed. If we were listing active vs inactive somewhere, could adjust – but likely just this flag.
* *Commit:* Commit the updated YAML (message “Archive repository `<name>`”).
* *Report:* Report success to Port.

**Notes:** Archiving is reversible (unarchive). We haven’t defined an “Unarchive” workflow, but it could be added similarly. For now, Port might consider unarchiving as an “update repository” operation or we simply have one if needed. The GitHub App requires permission to edit repository metadata for this.

We also consider if upon archiving we want to lock down any teams or settings – generally archiving retains the repo and its permissions, just read-only. We likely don’t need to remove teams, because their access just becomes read-only by virtue of archive. So no changes in team associations are needed.

### 8. **Delete Team**

**Trigger:** Invoked to completely delete a team from GitHub. Port might trigger this when a team entity is being removed (perhaps when a team is disbanded). Input: team name or ID.

**Steps:**

* *Validation:* Verify the team exists. Maybe check that the team is safe to delete (e.g., not owning any critical resources – but since team ownership isn’t an exclusive concept in GitHub beyond repo permissions, we just ensure the team’s repositories list is empty or not significant. Possibly Port would not allow deletion if the team still has associated repos; or we handle it by removing those first. We can integrate a check: if team still has repo access, optionally remove all or warn).
* *Provision:* Use Terraform or API:

  * Terraform: run `terraform destroy` on that team’s state file. This will remove the team via the provider. It should also remove any team memberships resources in state (which deletes the membership on GitHub, effectively just removing users from team, then team itself gets deleted). If the team had repos attached via Terraform state, those resources would be destroyed too (removing access). However, since we didn’t centrally manage team-repo links in Terraform state, we might not have those in state. So destroying the team resource in Terraform will delete the team, and GitHub automatically removes its repo permissions. This is fine.
  * API: call `DELETE /orgs/:org/teams/:team_slug`. GitHub will delete the team. That also implicitly removes all memberships and repo access. We might lean toward direct API here for simplicity (no state overhead), unless we want the Terraform state cleanup. Since we are tracking everything in YAML and Port anyway, API is acceptable.
  * **Port Update:** Remove the team entity from Port (or mark it deleted). Port might have a deletion endpoint or might treat deletion as just unlinking it from any blueprint. We should ensure Port knows the team is gone so it’s not shown in the catalog. If Port’s paradigm doesn’t automatically delete the entity on action completion, we might call an API to delete the entity by its ID. Otherwise, at least update a status.
* *YAML Update:* Remove the team’s YAML file from our GitOps repo. We don’t want to keep a record of a team that no longer exists (unless for historical audit, but since we have git history, we can recover it if needed). We will delete the file `teams/<team-name>.yaml`. Additionally, we should update any repository YAMLs that had this team in their access lists (remove it, since the team is gone). This could be a bulk search-and-update in our repo content. To automate: after deletion, use GitHub API or a cached list (Port or our data) to find which repos had that team. Perhaps our Port data can help (if Port knows relations, or we can search our YAMLs). The workflow can clone this repo, grep for `team-name` mentions in `repositories/*.yaml`, and edit those as needed. This is advanced but doable. We’ll implement at least scanning through repository YAML files in the action (since it’s small text). Remove the team references.
* *Commit:* Commit the removal of `teams/<team-name>.yaml` and any repo YAML changes. Commit message “Delete team `<team-name>`”. This commit shows as a deletion in git history.
* *Report:* Inform Port that the team deletion succeeded.

**Notes:** Deleting a team should be done cautiously if that team had broad access. But since the automation ensures cleanup of references, it’s fine. If any step fails (e.g., GitHub API fails to delete, or our grep misses something), we will log and possibly leave a note in AGENTS.md or an issue. Those edge cases aside, it’s straightforward.

### 9. **Add Environment to Repository** (Planned)

**Trigger:** This is a placeholder workflow for configuring a new **Deployment Environment** in a repository. In GitHub, environments are used for deployment gates, secrets, and protection rules (like requiring approvals before deployment, etc.). Port might trigger this when a team/project wants to add a new environment (say “staging” or “production”) to their repo for deployment pipelines to use. Inputs: repository name, environment name, and possibly settings like reviewers or secrets (though secrets likely provided out-of-band).

**Steps (envisioned):**

* *Validation:* Check repo exists. If environment name already exists in the repo, fail or handle idempotently (GitHub won’t allow duplicate env names).
* *Provision:* Currently, Terraform’s GitHub provider **does not support environments as a resource** (as of now, environment configs are not exposed to Terraform). So we will definitely use the GitHub API:

  * Create the environment: `POST /repos/:owner/:repo/environments` with name, or maybe it’s `PUT /repos/:owner/:repo/environments/:env_name` (GitHub API uses put to create/update env). Provide any deployment branch restrictions or wait timer if needed via API.
  * Set any required reviewers: there is an API to add required reviewers to an environment (e.g., `POST /repos/:owner/:repo/environments/:env_name/required_reviewers`). We can take input for team or user reviewers and call that.
  * We might also handle environment secrets creation if in scope, but that likely involves pulling secrets from somewhere (maybe Port provided them or a vault). Possibly out-of-scope for now.
  * Essentially configure the environment to desired state via API calls.
  * **Port Upsert:** In Port, create a new entity in an “Environment” blueprint (if one exists) or as part of the Repository blueprint’s sub-entity. Link it to the repository. Include properties like env name, associated repo, and any rules configured (maybe who the approvers are, etc.).
* *YAML:* Depending on how we store environment info. We have two choices:

  * Create separate YAML files per environment (e.g., `environments/<repo>--<env>.yaml` or a subfolder per repo). This might be clean as each env is an object.
  * Or embed environments in the repository’s YAML (like a section listing all envs and their settings). This is less file churn if many envs. However, separate files might be simpler to manage, especially if envs themselves have complex properties.
    We mentioned a top-level `/environments/` directory, which suggests each environment gets a file. We could name them `<repo>-<env>.yaml` or nest under an `/environments/<repo>/` folder. For simplicity, maybe `environments/<repo-name>__<env-name>.yaml` (use double underscore as delimiter, or some clear pattern). Inside that file, we store environment-specific config:

  ```yaml
  repo: <repo-name>
  environment: <env-name>
  reviewers: [ team-x, user-y ]
  deployment_branch: <branch name or pattern>
  ```

  etc.
  For now, we’ll plan on one file per environment in a flat `environments` directory or a nested structure.
* *Commit:* Add the new environment YAML (message “Add env `<env>` to `<repo>`”).
* *Report:* Return status to Port (with any details like environment URL – though envs are viewed within repo, not a standalone URL).

**Notes:** Because this workflow can be complex, we marked it as a placeholder to be fleshed out later. It will involve multiple GitHub API calls and careful structuring of YAML. For the current scope, we won’t implement fully, but it’s in the plan so the architecture accounts for it. The AI-generated code tasks for this can be deferred until the simpler ones are done.

## Key Design Decisions
- **Trunk-Based GitOps:** No pull requests; workflows running via Port will commit directly to `main` with changes.
- **Directory Structure:** One directory per entity type (e.g., `repositories/`, `teams/`, `environments/`). Each contains Terraform config and YAML files for each entity instance.
- **Workflows:** Located in `.github/workflows/`, one per action (create repo, create team, update team, etc.). They follow the 6-step pattern (validate, YAML, provision, update YAML, commit, report).
- **Terraform Usage:** Use Terraform GitHub provider for resources when possible (repos, teams, memberships, etc.). Use GitHub CLI or API for features not in provider (e.g., repository templates via cookiecutter, environment configs).
- **State Management:** Remote backend on Azure; state files segmented (e.g., one per repo or team) to keep them small and avoid conflicts. Use naming convention in backend config (like `repos/<name>.tfstate`).
- **Port Integration:** Port client ID/secret used to call Port’s API to create/update entities (Bluepint entries) and report action status. Each workflow parses a `port_payload` JSON input from Port to get context and user inputs.

## Conclusion

This design outlines a comprehensive plan for an automation repository that integrates Port with GitHub to manage org resources. We detailed the repository structure, secrets management, Terraform usage, and each required workflow’s logic. By following this plan, we can now implement each part step by step, using AI assistance to generate Terraform configurations and workflow files. The inclusion of `AGENTS.md` will ensure continuity between tasks.

Overall, this system will enable users to request resources through Port’s UI, have those requests automatically fulfilled in GitHub (with all the necessary settings and initial content), and have the results synced back to Port’s catalog — all while maintaining an auditable GitOps history of changes in this repository.&#x20;
