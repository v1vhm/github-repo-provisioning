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
  rulesets  = try(var.config.rulesets, [])
  labels    = try(var.config.labels, [])
  teams     = try(var.config.teams, [])
  variables = try(var.config.variables, [])
  secrets   = try(var.config.secrets, [])
}

resource "github_repository_ruleset" "rulesets" {
  for_each = var.apply_rulesets ? { for rs in local.rulesets : rs.name => rs } : {}

  name        = each.value.name
  repository  = var.repo
  target      = each.value.target
  enforcement = each.value.enforcement

  conditions {
    ref_name {
      include = try(each.value.conditions.ref_name.include, [])
      exclude = try(each.value.conditions.ref_name.exclude, [])
    }
  }

  rules {
    deletion         = contains([for r in each.value.rules : r.type], "deletion")
    non_fast_forward = contains([for r in each.value.rules : r.type], "non_fast_forward")

    dynamic "pull_request" {
      for_each = [for r in each.value.rules : r.parameters if r.type == "pull_request"]
      content {
        required_approving_review_count   = try(pull_request.value.required_approving_review_count, null)
        dismiss_stale_reviews_on_push     = try(pull_request.value.dismiss_stale_reviews_on_push, null)
        require_code_owner_review         = try(pull_request.value.require_code_owner_review, null)
        require_last_push_approval        = try(pull_request.value.require_last_push_approval, null)
        required_review_thread_resolution = try(pull_request.value.required_review_thread_resolution, null)
      }
    }

    dynamic "required_code_scanning" {
      for_each = [for r in each.value.rules : r.parameters if r.type == "code_scanning"]
      content {
        dynamic "required_code_scanning_tool" {
          for_each = try(required_code_scanning.value.code_scanning_tools, [])
          content {
            tool                      = required_code_scanning_tool.value.tool
            alerts_threshold          = try(required_code_scanning_tool.value.alerts_threshold, "all")
            security_alerts_threshold = try(required_code_scanning_tool.value.security_alerts_threshold, "all")
          }
        }
      }
    }

    dynamic "required_status_checks" {
      for_each = [for r in each.value.rules : r.parameters if r.type == "required_status_checks"]
      content {
        strict_required_status_checks_policy = try(required_status_checks.value.strict_required_status_checks_policy, null)
        do_not_enforce_on_create             = try(required_status_checks.value.do_not_enforce_on_create, null)

        dynamic "required_check" {
          for_each = try(required_status_checks.value.required_status_checks, [])
          content {
            context = required_check.value.context
          }
        }
      }
    }
  }
}

resource "github_issue_label" "labels" {
  for_each    = var.apply_labels ? { for l in local.labels : l.name => l } : {}
  repository  = var.repo
  name        = each.value.name
  color       = each.value.color
  description = each.value.description
}

data "github_team" "teams" {
  for_each = var.apply_teams ? { for t in local.teams : t.team => t } : {}
  slug     = each.key
}

resource "github_team_repository" "team_access" {
  for_each   = var.apply_teams ? { for t in local.teams : t.team => t } : {}
  team_id    = data.github_team.teams[each.key].id
  repository = var.repo
  permission = each.value.permission
}

resource "github_actions_variable" "variables" {
  for_each      = var.apply_variables ? { for v in local.variables : v.name => v } : {}
  repository    = var.repo
  variable_name = each.value.name
  value         = each.value.value
}

resource "github_actions_secret" "secrets" {
  for_each = var.apply_secrets ? {
    for s in local.secrets : s.name => s
    if contains(keys(var.secret_values), s.name)
  } : {}
  repository      = var.repo
  secret_name     = each.value.name
  plaintext_value = var.secret_values[each.value.name]
}
