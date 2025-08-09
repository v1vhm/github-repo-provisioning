variable "name" {
  description = "Name of the team"
  type        = string
}

variable "description" {
  description = "Team description"
  type        = string
  default     = ""
}

variable "privacy" {
  description = "Team privacy setting"
  type        = string
  default     = "closed"

  validation {
    condition     = contains(["secret", "closed"], var.privacy)
    error_message = "Privacy must be 'secret' or 'closed'."
  }
}

variable "members" {
  description = "List of usernames to add to the team"
  type        = list(string)
  default     = []
}
