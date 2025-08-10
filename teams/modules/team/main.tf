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

resource "github_team" "this" {
  name           = var.team_name
  description    = var.description
  privacy        = var.privacy
  parent_team_id = var.parent_team_slug != "" ? data.github_team.parent[0].id : null
}

resource "github_team_membership" "members" {
  for_each = { for m in var.members : m.username => m }
  team_id  = github_team.this.id
  username = each.value.username
  role     = each.value.role
}
