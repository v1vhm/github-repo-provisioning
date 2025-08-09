variable "name" {
  description = "Name of the repository"
  type        = string
}

variable "visibility" {
  description = "Repository visibility"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private", "internal"], var.visibility)
    error_message = "Visibility must be one of public, private, or internal."
  }
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = ""
}

variable "template" {
  description = "Template repository to use for initialization"
  type = object({
    owner      = string
    repository = string
  })
  default = null
}

variable "initial_team" {
  description = "Optional initial team attachment with permissions"
  type = object({
    id         = number
    permission = string
  })
  default = null
}
