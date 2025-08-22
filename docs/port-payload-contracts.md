# Port payload contracts

This document lists the JSON keys expected in the `port_payload` input for Port-triggered workflows. Each workflow assumes the payload includes the common fields below and may require additional properties under `properties`.

## Common fields
- `runId` – Port run identifier used for status updates
- `blueprint` – blueprint of the triggering entity in Port
- `requestedBy` – user who initiated the action in Port

## Workflow-specific properties

### create-repository.yml
**Required**
- `properties.port_product_identifier` – product identifier used to derive the repository name
- `properties.port_service_identifier` – service identifier used to derive the repository name
- `properties.port_service_description` – description of the repository
- `properties.port_repo_visibility` – repository visibility (`private`, `internal`, `public`)
- `properties.port_owning_team_slug` – slug of the team assigned as owner
- `properties.port_owner_team_permission` – permission granted to the owner team
- `properties.cookiecutter_template` – cookiecutter template used to scaffold the repo
- `properties.cookiecutter_user_context` – user-defined key/value variables passed to the template
- `properties.port_service_name` – standard cookiecutter input `port_service_name`
- `properties.port_cost_centre` – standard cookiecutter input `port_cost_centre`
- `properties.port_owning_team` – standard cookiecutter input `port_owning_team`
- `properties.port_owning_team_identifier` – standard cookiecutter input `port_owning_team_identifier`

The repository name is derived as `<port_product_identifier>-<port_service_identifier>`.

### update-repository.yml
**Required**
- `properties.repo_name` – name of the repository to update
**Optional**
- `properties.description` – new repository description
- `properties.visibility` – change repository visibility
- `properties.homepage_url` – set repository homepage URL
- `properties.topics` – list of topics to replace existing topics
- `properties.delete_branch_on_merge` – enable auto-deletion of merged branches
- `properties.enable_issues` – toggle Issues feature
- `properties.enable_wiki` – toggle Wiki feature
- `properties.default_branch` – set default branch name
- `properties.custom_properties` – map of custom key/values stored in the manifest

### add-team-to-repo.yml
**Required**
- `properties.repo_name` – repository receiving the team grant
- `properties.team_slug` – team to grant access to
- `properties.permission` – permission level (`pull`, `push`, etc.)
**Optional**
- `properties.mirror_on_team_manifest` – when true, also update the team manifest
- `properties.note` – text appended to commit message and Port log

### remove-team-from-repo.yml
**Required**
- `properties.repo_name` – repository from which to remove the team
- `properties.team_slug` – team whose access is revoked
**Optional**
- `properties.mirror_on_team_manifest` – when true, also remove repo from team manifest
- `properties.note` – text appended to commit message and Port log

### archive-repository.yml
**Required**
- `properties.repo_name` – repository to archive
**Optional**
- `properties.note` – text appended to commit message and Port log

### create-team.yml
**Required**
- `properties.team_name` – display name for the new team
- `properties.privacy` – team visibility (`closed` or `secret`)
**Optional**
- `properties.description` – team description
- `properties.parent_team_slug` – slug of parent team to nest under
- `properties.members` – list of `{username, role}` objects for initial members
- `properties.alias_slugs` – list of additional slugs referencing the team

### update-team.yml
**Required**
- `properties.team_slug` – slug of the team to update
**Optional**
- `properties.new_team_name` – new display name for the team
- `properties.description` – new description
- `properties.privacy` – new visibility (`closed` or `secret`)
- `properties.members_mode` – how to apply `members` (`set`, `add`, or `remove`)
- `properties.parent_team_slug` – assign or change parent team
- `properties.members` – list of `{username, role}` for membership changes
- `properties.aliases` – list of alias slugs to set on the team

### delete-team.yml
**Required**
- `properties.team_slug` – slug of the team to delete
**Optional**
- `properties.force` – proceed even if the team still has repository access
- `properties.note` – text appended to commit message and Port log

### add-environment.yml
**Required**
- `github_repository` – repository receiving the environment
- `environment_identifier` – name of the environment to create
- `service_identifier` – service linked to the environment
- `environment_location` – deployment region for the environment
- `environment_resource_group` – Azure resource group backing the environment
- `managed_identity_client_id` – client ID for the managed identity
- `request_identifier` – Port request identifier
- `environment_type` – type of environment (`development`, `production`, etc.)
**Optional**
- `state_file_container` – Azure storage container for Terraform state
- `state_file_resource_group` – resource group for Terraform state
- `state_file_storage_account` – storage account for Terraform state

