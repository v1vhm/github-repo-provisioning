variable "org" {
  type = string
}

variable "team_name" {
  type    = string
  default = ""
}

variable "team_slug" {
  type    = string
  default = ""
}

variable "privacy" {
  type    = string
  default = "closed"
  validation {
    condition     = contains(["closed", "secret"], var.privacy)
    error_message = "Privacy must be 'closed' or 'secret'."
  }
}

variable "description" {
  type    = string
  default = ""
}

variable "parent_team_slug" {
  type    = string
  default = ""
}

variable "members" {
  type    = list(object({ username = string, role = string }))
  default = null
}
