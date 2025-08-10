variable "org" { type = string }
variable "repo_name" { type = string }
variable "description" { type = string }
variable "visibility" { type = string }

variable "homepage_url" {
  type    = string
  default = null
}

variable "topics" {
  type    = list(string)
  default = []
}

variable "delete_branch_on_merge" {
  type    = bool
  default = true
}

variable "enable_issues" {
  type    = bool
  default = true
}

variable "enable_wiki" {
  type    = bool
  default = false
}

variable "default_branch" {
  type    = string
  default = null
}

variable "owner_team_slug" {
  type    = string
  default = null
}

variable "owner_perm" {
  type    = string
  default = null
}

variable "archived" {
  type    = bool
  default = false
}
