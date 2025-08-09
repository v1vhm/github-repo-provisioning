output "repo_id" {
  value = github_repository.this.node_id
}

output "html_url" {
  value = github_repository.this.html_url
}

output "ssh_url" {
  value = github_repository.this.ssh_clone_url
}
