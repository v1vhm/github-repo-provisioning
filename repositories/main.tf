terraform {
  required_version = ">= 1.5.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {}

resource "github_repository" "this" {
  name        = var.name
  visibility  = var.visibility
  description = var.description

  dynamic "template" {
    for_each = var.template == null ? [] : [var.template]
    content {
      owner      = template.value.owner
      repository = template.value.repository
    }
  }
}

resource "github_team_repository" "initial" {
  count      = var.initial_team == null ? 0 : 1
  team_id    = var.initial_team.id
  repository = github_repository.this.name
  permission = var.initial_team.permission
}
