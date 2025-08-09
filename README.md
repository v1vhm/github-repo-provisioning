# Port GitHub Automation

This repository automates the creation and management of GitHub repositories, teams, and environments. Automation is triggered by Port and executed through GitHub Actions workflows using Terraform for provisioning.

## Repository Structure
- `repositories/` - Terraform module to manage GitHub repositories.
- `teams/` - Terraform module for GitHub teams.
- `environments/` - Terraform module for environment configurations.
- `.github/workflows/` - GitHub Actions workflows.
- `.github/actions/` - Reusable GitHub Actions.

Refer to `AGENTS.md` for design decisions and the task list.

