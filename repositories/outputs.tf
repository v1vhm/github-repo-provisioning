output "repository_id" {
  description = "The ID of the created repository"
  value       = github_repository.this.node_id
}

output "repository_full_name" {
  description = "The full name of the created repository"
  value       = github_repository.this.full_name
}
