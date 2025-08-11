variable "owner" { type = string }
variable "repo" { type = string }
variable "config" { type = any }

variable "apply_rulesets" {
  type    = bool
  default = true
}

variable "apply_labels" {
  type    = bool
  default = true
}

variable "apply_teams" {
  type    = bool
  default = true
}

variable "apply_variables" {
  type    = bool
  default = true
}

variable "apply_secrets" {
  type    = bool
  default = true
}

variable "secret_values" {
  type    = map(string)
  default = {}
}
