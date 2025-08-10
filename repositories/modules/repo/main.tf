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

resource "github_repository" "this" {
  name         = var.repo_name
  description  = var.description
  visibility   = var.visibility
  homepage_url = var.homepage_url
  topics       = var.topics

  has_issues             = var.enable_issues
  has_wiki               = var.enable_wiki
  delete_branch_on_merge = var.delete_branch_on_merge
  archived               = var.archived
  lifecycle { prevent_destroy = true }
}

data "github_team" "owner" {
  count = var.owner_team_slug == null ? 0 : 1
  slug  = var.owner_team_slug
}

resource "github_team_repository" "owner_access" {
  count      = var.owner_team_slug == null ? 0 : 1
  team_id    = data.github_team.owner[0].id
  repository = github_repository.this.name
  permission = var.owner_perm
}

resource "github_branch_default" "default" {
  count      = var.default_branch == null ? 0 : 1
  repository = github_repository.this.name
  branch     = var.default_branch
}
