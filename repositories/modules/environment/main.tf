terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = var.owner
}

locals {
  phases = ["plan", "apply"]
}

resource "github_repository_environment" "this" {
  for_each    = toset(local.phases)
  repository  = var.repository
  environment = "${var.environment_name}-${each.key}"
}

resource "github_actions_environment_secret" "azure_client_id" {
  for_each        = github_repository_environment.this
  repository      = var.repository
  environment     = each.value.environment
  secret_name     = "AZURE_CLIENT_ID"
  plaintext_value = var.managed_identity_client_id
}
