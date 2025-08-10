terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = var.org
}

data "github_team" "parent" {
  count = var.parent_team_slug != "" ? 1 : 0
  slug  = var.parent_team_slug
}

locals {
  resolved_team_name = var.team_name != "" ? var.team_name : var.team_slug
}

resource "github_team" "this" {
  name           = local.resolved_team_name
  description    = var.description
  privacy        = var.privacy
  parent_team_id = var.parent_team_slug != "" ? data.github_team.parent[0].id : null

  lifecycle {
    precondition {
      condition     = local.resolved_team_name != ""
      error_message = "team_name or team_slug must be provided"
    }
  }
}

resource "github_team_membership" "members" {
  for_each = var.members != null ? { for m in var.members : m.username => m } : {}
  team_id  = github_team.this.id
  username = each.value.username
  role     = each.value.role
}
