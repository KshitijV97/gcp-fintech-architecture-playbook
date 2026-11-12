output "folder_ids" {
  value = { for k, f in google_folder.this : k => f.name }
}

output "kms_project_ids" {
  value = {
    eu = module.kms_eu.project_id
    ca = module.kms_ca.project_id
  }
}

output "shared_vpc_eu" {
  value = {
    host_project = module.net_host_eu.project_id
    network_id   = module.shared_vpc_eu.network_id
    subnets      = module.shared_vpc_eu.subnets
  }
}

output "audit_log_bucket" {
  value = module.audit_logging.log_bucket_id
}
