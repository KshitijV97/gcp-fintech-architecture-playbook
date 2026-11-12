variable "project_id" {
  description = "Central KMS project."
  type        = string
}

variable "location" {
  description = "Key ring location. Must match the location of the resources it protects (e.g. europe-west3, or 'europe' for EU multi-region resources)."
  type        = string
}

variable "key_ring_name" {
  type = string
}

variable "keys" {
  description = "Map of key name => settings."
  type = map(object({
    data_domain                = string
    protection_level           = optional(string, "HSM")
    rotation_period            = optional(string, "7776000s") # 90 days
    destroy_scheduled_duration = optional(string, "86400s")   # 24 hours
  }))

  validation {
    condition     = alltrue([for k in values(var.keys) : contains(["SOFTWARE", "HSM", "EXTERNAL", "EXTERNAL_VPC"], k.protection_level)])
    error_message = "protection_level must be SOFTWARE, HSM, EXTERNAL or EXTERNAL_VPC."
  }
}

variable "encrypters" {
  description = "Map of key name => list of IAM members (usually Google service agents) granted Encrypter/Decrypter."
  type        = map(list(string))
  default     = {}
}

variable "labels" {
  type    = map(string)
  default = {}
}
