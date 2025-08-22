output "environment_ids" {
  value = { for k, env in github_repository_environment.this : k => env.id }
}

output "environment_names" {
  value = { for k, env in github_repository_environment.this : k => env.environment }
}
