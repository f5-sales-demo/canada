variable "subscription_id" { type = string }
variable "storage_account_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Use a globally unique lowercase storage account name."
  }
}
variable "workstation_egress_ips" {
  type = set(string)
  validation {
    condition = length(var.workstation_egress_ips) == 2 && alltrue([
      for ip in var.workstation_egress_ips : can(cidrnetmask("${ip}/32")) && !strcontains(ip, "/")
    ])
    error_message = "Supply both verified workstation public IPv4 addresses without CIDR suffixes."
  }
}
variable "operator_principal_id" { type = string }
