# Port GitHub Automation

This repository automates the creation and management of GitHub repositories, teams, and environments. Automation is triggered by Port and executed through GitHub Actions workflows using Terraform for provisioning.

## Repository Structure
- `repositories/` - Terraform module to manage GitHub repositories.
- `teams/` - Terraform module for GitHub teams.
- `environments/` - Terraform module for environment configurations.
- `.github/workflows/` - GitHub Actions workflows.
- `.github/actions/` - Reusable GitHub Actions.

Port catalog updates and run status reporting leverage the official [`port-labs/port-github-action`](https://github.com/port-labs/port-github-action).

Refer to `AGENTS.md` for design decisions and the task list.

## Secrets and Variables

The GitHub Actions workflows rely on several repository secrets (and
optionally variables) for authentication and state management. Configure
the following in the repository settings before running the workflows:

### Secrets

- `GH_APP_ID` – GitHub App identifier used to mint installation tokens
- `GH_APP_PRIVATE_KEY` – private key for the GitHub App
- `GH_APP_INSTALLATION_ID` – installation ID of the GitHub App in the organization
- `GH_ORG` – name of the GitHub organization
- `AZURE_CLIENT_ID` – Azure AD application (service principal) client ID for OIDC
- `AZURE_TENANT_ID` – Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` – Azure subscription containing the storage account
- `AZURE_RESOURCE_GROUP` – resource group of the storage account
- `AZURE_STORAGE_ACCOUNT` – Azure Storage account for Terraform state
- `AZURE_STORAGE_CONTAINER` – container name for Terraform state files
- `PORT_CLIENT_ID` – Port OAuth client ID
- `PORT_CLIENT_SECRET` – Port OAuth client secret
- `COOKIECUTTER_GIT_AUTH` – (optional) token for private cookiecutter templates

### Variables

Currently none are required, but repository variables can be added for
non‑sensitive configuration.

