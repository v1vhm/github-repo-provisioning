output "environment_id" {
  value = github_repository_environment.this.id
}

output "environment_name" {
  value = github_repository_environment.this.environment
}
