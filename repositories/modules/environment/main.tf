terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

resource "github_repository_environment" "this" {
  repository  = var.repository
  environment = var.environment_name
}

resource "github_actions_environment_secret" "azure_client_id" {
  repository      = var.repository
  environment     = github_repository_environment.this.environment
  secret_name     = "AZURE_CLIENT_ID"
  plaintext_value = var.managed_identity_client_id
}
