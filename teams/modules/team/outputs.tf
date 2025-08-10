output "team_id" {
  value = github_team.this.id
}

output "slug" {
  value = github_team.this.slug
}

output "html_url" {
  value = "https://github.com/orgs/${var.org}/teams/${github_team.this.slug}"
}
