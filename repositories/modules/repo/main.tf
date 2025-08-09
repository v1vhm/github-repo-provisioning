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

data "github_team" "owner" {
  slug = var.owner_team_slug
}

resource "github_repository" "this" {
  name        = var.repo_name
  description = var.description
  visibility  = var.visibility

  has_issues             = true
  has_wiki               = false
  delete_branch_on_merge = true
}

resource "github_team_repository" "owner_access" {
  team_id    = data.github_team.owner.id
  repository = github_repository.this.name
  permission = var.owner_perm
}
