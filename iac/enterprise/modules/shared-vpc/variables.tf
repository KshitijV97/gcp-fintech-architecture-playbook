variable "host_project_id" {
  type = string
}

variable "network_name" {
  type = string
}

variable "subnets" {
  description = "Subnets keyed by name."
  type = map(object({
    region           = string
    cidr             = string
    secondary_ranges = optional(map(string), {})
  }))
}

variable "psa_cidr" {
  description = "CIDR reserved for Private Services Access (managed DBs)."
  type        = string
  default     = "10.250.0.0/16"
}
