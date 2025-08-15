# Port GitHub Automation

This repository automates the creation and management of GitHub repositories, teams, and environments. Automation is triggered by Port and executed through GitHub Actions workflows using Terraform for provisioning.

## Repository Structure
- `repositories/` - Terraform module to manage GitHub repositories.
- `teams/` - Terraform module for GitHub teams.
- `.github/workflows/` - GitHub Actions workflows.
- `.github/actions/` - Reusable GitHub Actions.

Port catalog updates and run status reporting leverage the official [`port-labs/port-github-action`](https://github.com/port-labs/port-github-action).

Refer to `AGENTS.md` for design decisions and the task list.

## Repository Configuration

Repository templates include `.provisioning/repository-config.yml`, a YAML file
that defines initial settings such as branch rulesets, default labels, team
permissions, Actions variables and secrets. The `create-repository` workflow
parses this file in a **Configure repository** block and applies it using the
`modules/github-initial-config` Terraform module. The block:

1. Clones the template to read `.provisioning/repository-config.yml`.
2. Maps any `workflow_secret` references in the file to provided secrets.
3. Runs the module to create rulesets, labels, team access, variables and
   secrets.
4. Removes the local Terraform directory and state files, keeping this
   configuration state ephemeral.

## Secrets and Variables

The GitHub Actions workflows rely on several repository secrets (and
optionally variables) for authentication and state management. Configure
the following in the repository settings before running the workflows:

### Secrets

- `GH_APP_ID` – GitHub App identifier used to mint installation tokens
- `GH_APP_PRIVATE_KEY` – private key for the GitHub App
- `GH_APP_INSTALLATION_ID` – installation ID of the GitHub App in the organization
- `AZURE_CLIENT_ID` – Azure AD application (service principal) client ID for OIDC
- `AZURE_TENANT_ID` – Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` – Azure subscription containing the storage account
- `AZURE_RESOURCE_GROUP` – resource group of the storage account
- `AZURE_STORAGE_ACCOUNT` – Azure Storage account for Terraform state
- `AZURE_STORAGE_CONTAINER` – container name for Terraform state files
- `PORT_CLIENT_ID` – Port OAuth client ID
- `PORT_CLIENT_SECRET` – Port OAuth client secret
- `COOKIECUTTER_GIT_AUTH` – (optional) token for private cookiecutter templates

The GitHub organization is derived from the repository owner (`github.repository_owner`), so no separate `GH_ORG` secret is needed.

### Variables

Currently none are required, but repository variables can be added for
non‑sensitive configuration.

## Local testing and CI

Sample Port payloads live under `tests/payloads/` for running workflows
locally with [`act`](https://github.com/nektos/act). The companion
`tests/README.md` explains how to execute workflows with these payloads
and how to run a mock invocation using `--dryrun`.

CI enforces [`actionlint`](https://github.com/rhysd/actionlint),
[`tflint`](https://github.com/terraform-linters/tflint), and
`terraform validate` on all modules. Run these checks locally before
submitting changes:

```bash
actionlint
terraform -chdir=repositories/modules/repo init -backend=false
terraform -chdir=repositories/modules/repo validate
tflint --chdir repositories/modules/repo
terraform -chdir=teams/modules/team init -backend=false
terraform -chdir=teams/modules/team validate
tflint --chdir teams/modules/team
```


