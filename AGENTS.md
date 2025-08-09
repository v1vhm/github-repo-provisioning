# AI Development Agents Context

This file provides context and guidelines for AI agents contributing to the "Port GitHub Automation" repository. It describes the project, decisions made so far, and the tasks to be completed. **After completing any task, update this file to reflect changes or new decisions.**

## Project Overview
- **Purpose:** Automate the creation and management of GitHub repositories and teams, triggered by Port. All changes are recorded in this repo as YAML files (GitOps style).
- **Tech Stack:** GitHub Actions workflows (YAML) orchestrating Terraform and occasional scripts/CLI. Terraform state stored in Azure Blob storage. GitHub App credentials for auth, Port API for catalog updates.
- **Plan:** refer to the file `PLAN.md` for detailed design information about the repository.

## Key Design Decisions
- **Trunk-Based GitOps:** No pull requests; workflows running via Port will commit directly to `main` with changes.
- **Directory Structure:** One directory per entity type (e.g., `repositories/`, `teams/`, `environments/`). Each contains Terraform config and YAML files for each entity instance.
- **Workflows:** Located in `.github/workflows/`, one per action (create repo, create team, update team, etc.). They follow the 6-step pattern (validate, YAML, provision, update YAML, commit, report).
- **Terraform Usage:** Use Terraform GitHub provider for resources when possible (repos, teams, memberships, etc.). Use GitHub CLI or API for features not in provider (e.g., repository templates via cookiecutter, environment configs).
- **State Management:** Remote backend on Azure; state files segmented (e.g., one per repo or team) to keep them small and avoid conflicts. Use naming convention in backend config (like `repos/<name>.tfstate`).
- **Port Integration:** Port client ID/secret used to call Port’s API to create/update entities (Bluepint entries) and report action status. Each workflow parses a `port_payload` JSON input from Port to get context and user inputs.

## Implementation Tasks
Below is the breakdown of tasks to be implemented. Each task should be undertaken by an AI agent sequentially. **Agents: mark tasks as done and update context when completed.**

1. ~~Scaffold Repository Structure~~: Basic directory layout created (`repositories/`, `teams/`, `environments/`, `.github/workflows/`, `.github/actions/`) with placeholder Terraform files and README.
2. ~~Implement GitHub App Authentication~~: Workflows will use `actions/create-github-app-token@v1` directly to obtain installation tokens using `APP_ID` and `APP_PRIVATE_KEY` secrets.
3. ~~Terraform Module – Repository~~: Implemented Terraform config in `repositories/` (`main.tf`, `variables.tf`, `outputs.tf`) creating a GitHub repository with configurable name, visibility, description, optional template, and optional initial team attachment. Tested with a dry run.
4. ~~Terraform Module – Team~~: Implemented Terraform config in `teams/` creating a GitHub team with configurable name, description, privacy, and optional member addition.
5. ~~Workflow – Create Repository~~: Workflow `create-repository.yml` provisions repos via Terraform and cookiecutter, commits manifests, and upserts to Port using composite actions. A validation script checks naming and uniqueness.
6. **Workflow – Create Team**: Develop `.github/workflows/create-team.yml`. Parse payload (team name, members, etc.), validate, Terraform apply in `teams/`, commit YAML, update Port.
7. **Workflow – Update Team**: Develop `.github/workflows/update-team.yml`. Parse payload (team id/name, new members or changes), validate, either Terraform apply or API calls to adjust membership, update YAML, commit, update Port.
8. **Workflow – Update Repository**: Develop `.github/workflows/update-repository.yml`. Parse payload (repo name, properties to change), validate, Terraform apply changes, update YAML, commit, update Port.
9. **Workflow – Add Team to Repo**: `.github/workflows/add-team-to-repo.yml`. Validate inputs, use GitHub CLI or Terraform to grant access, update YAML(s), commit, update Port.
10. **Workflow – Remove Team from Repo**: `.github/workflows/remove-team-from-repo.yml`. Similar to above, revoke access, update YAML(s), commit, update Port.
11. **Workflow – Archive Repository**: `.github/workflows/archive-repository.yml`. Validate, call Terraform or API to archive, update YAML, commit, update Port.
12. **Workflow – Delete Team**: `.github/workflows/delete-team.yml`. Validate, delete via Terraform or API, update/remove YAML(s), commit, update Port.
13. **Placeholder – Add Environment**: `.github/workflows/add-environment.yml`. (Design stub for now; actual implementation later.)
14. **Reusable Components**: Refactor common code. E.g., create a composite action for committing YAML (stage, commit, push), one for Port API calls (to avoid rewriting curl logic), and one for Terraform apply steps. Update workflows to use these.
15. **Testing & Validation**: Write example dummy Port payloads and test workflows locally (using `act` or in a test repo) to ensure logic works. Adjust as needed.
16. **Documentation**: Update README.md with instructions on how Port triggers the workflows, what each workflow does, and how to configure the GitHub App and Azure backend.

*Note:* After completing each task, **update this list**, mark tasks as done (e.g., ~~task~~ or a checkmark), and add any new insights or required changes to the design above. Keep this file up-to-date so that the next agent has the latest context.

### Notes
 - Composite action `commit-yaml` introduced; Port interactions now use `port-labs/port-action`.
 - Terraform state backend authenticates to Azure via OIDC; configure `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_STORAGE_ACCOUNT`, and `AZURE_STORAGE_CONTAINER` secrets.
 - Future improvement: reusable action to mint GitHub App tokens.
 - README now documents required secrets and variables.
