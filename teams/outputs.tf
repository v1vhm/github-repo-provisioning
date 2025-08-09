output "team_id" {
  description = "The ID of the created team"
  value       = github_team.this.id
}

output "team_slug" {
  description = "The slug of the created team"
  value       = github_team.this.slug
}
