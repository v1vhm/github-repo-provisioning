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

resource "github_team" "this" {
  name        = var.name
  description = var.description
  privacy     = var.privacy
}

resource "github_team_membership" "members" {
  for_each = toset(var.members)
  team_id  = github_team.this.id
  username = each.value
  role     = "member"
}
