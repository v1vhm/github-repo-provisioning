output "ruleset_ids" {
  value = { for k, v in github_repository_ruleset.rulesets : k => v.id }
}
