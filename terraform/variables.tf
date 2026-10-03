variable "admin_username" {
  description = "SSH admin username for the VMs."
  type        = string
  default     = "azureuser"
}

variable "approve_registration" {
  description = "Approve each CE's runtime registration from Terraform (the xcsh_site_registration data source resolves the r-<uuid> registration name from the site name, and xcsh_registration_approval approves it). Two-phase by nature: the registration only exists after the CE has booted and registered, so the first apply plans no approval and a later apply creates it. Set false to leave approval to an operator."
  type        = bool
  default     = true
}

variable "azure_frr_asn" {
  description = "ASN shared by the two independent FRR relays in each Azure region."
  type        = number
  default     = 65020

  validation {
    condition     = var.azure_frr_asn >= 64512 && var.azure_frr_asn <= 65534 && !contains([var.ce_asn, var.rs_asn], var.azure_frr_asn)
    error_message = "azure_frr_asn must be a private ASN distinct from CE and Route Server ASNs."
  }
}

variable "ca_bastion_name" {
  description = "Canada Azure Bastion host name. Leave null to derive `<component>-ca-bastion`."
  type        = string
  default     = null
}

variable "ca_bastion_subnet_prefix" {
  description = "Canada AzureBastionSubnet prefix. MUST be /26 or larger."
  type        = string
  default     = "10.200.5.0/26"

  validation {
    condition     = tonumber(split("/", var.ca_bastion_subnet_prefix)[1]) <= 26
    error_message = "ca_bastion_subnet_prefix must be /26 or larger."
  }
}

variable "ca_ce_count" {
  description = "Number of Canadian single-node Secure Mesh v2 CE sites (1..3)."
  type        = number
  default     = 3

  validation {
    condition     = var.ca_ce_count >= 1 && var.ca_ce_count <= 3
    error_message = "ca_ce_count must be between 1 and 3."
  }
}

variable "ca_ce_vsite_name" {
  description = "Name of the Canadian Customer Edge virtual site. Leave null (the default) to derive `<component>-ca-ce-vsite`."
  type        = string
  default     = null
}

variable "ca_client_vm_name" {
  description = "Canada test client VM name. Leave null to derive `<component>-ca-client`."
  type        = string
  default     = null
}

variable "ca_external_subnet_prefix" {
  description = "Canada snet-hub-external prefix."
  type        = string
  default     = "10.200.2.0/26"
}

variable "ca_hub_cidr" {
  description = "Canada Hub VNet address space."
  type        = string
  default     = "10.200.0.0/16"
}

variable "ca_internal_subnet_prefix" {
  description = "Canada snet-hub-internal prefix. Test client lives here."
  type        = string
  default     = "10.200.3.0/26"
}

variable "ca_lb_domain" {
  description = "Domain served by the Canada HTTP load balancer. Supply the existing Canadian hostname through private inputs."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.ca_lb_domain))
    error_message = "ca_lb_domain must be a fully-qualified lowercase domain name (for example canada.example.com)."
  }
}

variable "ca_lb_name" {
  description = "Name of the Canada HTTP load balancer. Leave null (the default) to derive `<component>-ca-f5se`."
  type        = string
  default     = null
}

variable "ca_location" {
  description = "Azure region for Canadian regional resources."
  type        = string
  default     = "canadacentral"
  validation {
    condition     = contains(["canadacentral", "canadaeast"], var.ca_location)
    error_message = "Canadian regional resources must use Canada Central or Canada East."
  }
}

variable "ca_mgmt_subnet_prefix" {
  description = "Canada snet-hub-management prefix. CE eth0/SLO NICs live here."
  type        = string
  default     = "10.200.1.0/26"
}

variable "ca_origin_ip" {
  description = "Canadian external origin IPv4 address when the owned showcase origins are disabled. Set this for externally hosted Canadian origins."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.ca_origin_ip == null || can(cidrhost("${var.ca_origin_ip}/32", 0))
    error_message = "ca_origin_ip must be a valid IPv4 address."
  }
}

variable "ca_origin_pool_name" {
  description = "Name of the Canada origin pool. Leave null (the default) to derive `<component>-ca-pool`."
  type        = string
  default     = null
}

variable "ca_re_cities" {
  description = "List of cities for the Canadian Regional Edge Virtual Site selector. Defaults to Toronto and Montreal."
  type        = list(string)
  default     = ["toronto", "montreal"]
  validation {
    condition = (
      length(var.ca_re_cities) > 0 &&
      alltrue([for city in var.ca_re_cities : contains(["toronto", "montreal"], city)])
    )
    error_message = "Canadian RE advertisement must select Toronto and/or Montreal."
  }
}

variable "ca_re_public_ip" {
  description = "Dedicated XC public-IP allocation reserved for this Canadian demo. Use an existing unused allocation or obtain an additional one through F5 support; keep the actual allocation in private tfvars."
  type = object({
    name      = string
    namespace = string
    ip        = string
  })
  default  = null
  nullable = true
  validation {
    condition = var.ca_re_public_ip == null || try(
      length(var.ca_re_public_ip.name) > 0 &&
      length(var.ca_re_public_ip.namespace) > 0 &&
      can(cidrhost("${var.ca_re_public_ip.ip}/32", 0)) &&
    !strcontains(var.ca_re_public_ip.ip, ":"), false)
    error_message = "ca_re_public_ip must identify an allocated IPv4 public-IP object by name and namespace."
  }
}

variable "ca_re_vsite_name" {
  description = "Name of the Canadian Regional Edge virtual site. Leave null (the default) to derive `<component>-ca-re-vsite`."
  type        = string
  default     = null
}

variable "ca_region_short" {
  description = "Short region token for Canada site names. Leave null to use var.ca_location."
  type        = string
  default     = null
}

variable "ca_resource_group_name" {
  description = "Resource group that holds the Canadian hub VNet, Route Server, CE VMs and test client. Leave null (the default) to derive `rg-<component>-ca-<deployer>`."
  type        = string
  default     = null
}

variable "ca_route_server_name" {
  description = "Canada Azure Route Server name. Leave null to derive `<component>-ca-rs`."
  type        = string
  default     = null
}

variable "ca_route_server_subnet_prefix" {
  description = "Canada RouteServerSubnet prefix. MUST be exactly /27."
  type        = string
  default     = "10.200.4.0/27"

  validation {
    condition     = tonumber(split("/", var.ca_route_server_subnet_prefix)[1]) == 27
    error_message = "ca_route_server_subnet_prefix must be a /27."
  }
}

variable "ca_site_prefix" {
  description = "Prefix for Canadian XC site names (site = <ca_site_prefix>-<ca_region_short>0<n>). Leave null to derive `<component>-ca`."
  type        = string
  default     = null
}

variable "ca_vip" {
  description = "HA VIP for Canadian CEs advertised as a /32 via eBGP."
  type        = string
  default     = "10.250.1.10"

  validation {
    condition     = can(cidrhost("${var.ca_vip}/32", 0))
    error_message = "ca_vip must be a valid IPv4 address."
  }
}

variable "ce_asn" {
  description = "BGP ASN for the Customer Edge nodes (eBGP local ASN)."
  type        = number
  default     = 64512
}

variable "ce_os_version" {
  description = "CE OS version, set at create time. Empty deliberately selects the newest version advertised by F5 Distributed Cloud; the CE module now enforces an 80 GB disk default for the pinned Marketplace image. A concrete value is for reproducing an older build. Terraform cannot change this field afterwards: updates are rejected in every direction, including un-pinning. The platform can change it in place through the site upgrade_os action, but the provider cannot drive that action yet (xcsh#1390)."
  type        = string
  default     = ""
}

variable "ce_sw_version" {
  description = "CE F5 Distributed Cloud software version, set at create time. Empty deliberately selects the newest advertised build; the CE module now enforces an 80 GB disk default for the pinned Marketplace image. A concrete value is for reproducing an older build. The node always installs a destination build on first boot. Terraform cannot change this field afterwards, but the platform can change it in place through the site upgrade_sw action (xcsh#1390)."
  type        = string
  default     = ""
}

variable "ce_vm_size" {
  description = "VM size for the Customer Edge nodes."
  type        = string
  default     = "Standard_D8_v4"
}

variable "component" {
  description = "Component name used in tags."
  type        = string
  default     = "canada-topology"
}

variable "deployer" {
  description = "Override for the deployer identifier used in tags (auto-resolved from Azure AD when empty)."
  type        = string
  default     = ""
}

variable "deployment_actor_id" {
  description = "Non-personal stable identifier for the automation actor that applies the deployment."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.deployment_actor_id))
    error_message = "deployment_actor_id must be a 3-63 character lowercase non-personal identifier."
  }
}

variable "deployment_owner_id" {
  description = "Non-personal stable identifier for the team or service that owns the deployment."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.deployment_owner_id))
    error_message = "deployment_owner_id must be a 3-63 character lowercase non-personal identifier."
  }
}

variable "enable_azure" {
  description = "Deploy the Azure US and Canada SMSv2 graphs. Keep true for the full showcase; set false only for the separately reviewed AWS-only saved-plan and preflight stage."
  type        = bool
  default     = true
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion so developers can reach each CE's Site Console web UI (https://<sli-ip>:65500) with Azure RBAC instead of an SSH key and a jump host."
  type        = bool
  default     = false
}

variable "enable_bgp" {
  description = "Enable both regional CE-to-FRR and FRR-to-Route-Server BGP paths alongside the ILB application path."
  type        = bool
  default     = true
}

variable "enable_canada" {
  description = "Enable parallel Canada-only regional infrastructure, Canadian virtual sites, and f5-sales-demo.ca load balancer."
  type        = bool
  default     = true
}

variable "enable_canada_ilb" {
  description = "Deploy the Canadian inside application and Site Console ILB frontends alongside the BGP path."
  type        = bool
  default     = true
}

variable "enable_canada_public_re" {
  description = "Advertise the Canadian HTTP-LB publicly on Toronto/Montreal using a dedicated allocated XC public IP. Requires ca_re_public_ip."
  type        = bool
  default     = false
}

variable "enable_showcase_origin" {
  description = "Deploy a disposable Canadian HTTP origin for repeatable traffic verification."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment label used in tags."
  type        = string
  default     = "lab"
}

variable "expected_xc_tenant" {
  description = "F5 XC tenant this deployment belongs to: the first hostname label of the console URL (`f5-sales-demo` for https://f5-sales-demo.console.ves.volterra.io). This is the ONLY place the tenant is named. The xcsh provider's api_url is derived from it, so the configuration — not the ambient environment — decides which tenant is written to, and a plan FAILS when XCSH_API_URL in the environment names a different one."
  type        = string
  default     = "f5-sales-demo"

  validation {
    # A hostname label, not a URL: the scheme and domain are added in locals.tf.
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.expected_xc_tenant))
    error_message = "expected_xc_tenant must be a bare DNS label (lowercase letters, digits and hyphens) such as f5-sales-demo — not a URL and not a hostname."
  }
}

variable "origin_developer_cidrs" {
  description = "Explicit workstation public IPv4 /32 addresses allowed to reach the demo origin for development. Keep allocations in private tfvars."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for cidr in var.origin_developer_cidrs : can(cidrhost(cidr, 0)) && endswith(cidr, "/32") && !strcontains(cidr, ":")])
    error_message = "Developer origin access requires exact public IPv4 /32 addresses."
  }
}

variable "origin_port" {
  description = "TCP port of the origin server."
  type        = number
  default     = 80
}

variable "registration_token" {
  description = "Optional override for the Azure CE cloud-init site registration token. When empty (the default), enabled Azure CE nodes use the provider-generated xcsh_token.ce[0].uid; set a non-empty value to inject an externally-minted token instead."
  type        = string
  default     = ""
  sensitive   = true
}

variable "rs_asn" {
  description = "BGP ASN of the Azure Route Server (fixed by Azure at 65515)."
  type        = number
  default     = 65515
}

variable "site_prefix" {
  description = "Prefix for XC site names (site = <prefix>-<region_short>0<n>). Leave null to use the released SMSv2 identity generation derived from var.component. Renaming a site replaces the CE VM, because the site name is the ClusterName baked into cloud-init and cloud-init only runs on first boot."
  type        = string
  default     = null
}

variable "smsv2_site_generation" {
  description = "Immutable identity generation appended to the default SMSv2 site prefix. The released default deliberately avoids the legacy canada-ce-ha-* global-name reservations; do not decrement or reuse an earlier generation."
  type        = string
  default     = "smsv2"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.smsv2_site_generation))
    error_message = "smsv2_site_generation must be a DNS-style label: lowercase alphanumerics and hyphens, not starting or ending with a hyphen."
  }
}

variable "source_commit_sha" {
  description = "Immutable lowercase 40-hex commit that was reviewed and used to create the saved plan."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.source_commit_sha))
    error_message = "source_commit_sha must be an immutable lowercase 40-hex Git commit."
  }
}

variable "source_ref" {
  description = "Exact trusted branch ref of the reviewed source. PR merge refs and abbreviated branch names are rejected."
  type        = string

  validation {
    condition = (
      can(regex("^refs/heads/[^[:cntrl:][:space:]~^:?*\\\\\\[]+$", var.source_ref)) &&
      !strcontains(var.source_ref, "..") &&
      !strcontains(var.source_ref, "@{") &&
      !strcontains(var.source_ref, "//") &&
      !can(regex("(^refs/heads/|/)\\.", var.source_ref)) &&
      !can(regex("(\\.|\\.lock)(/|$)", var.source_ref)) &&
      var.source_ref != "refs/heads/@" &&
      !endswith(var.source_ref, "/")
    )
    error_message = "source_ref must be a valid exact refs/heads/* ref, never refs/pull/* or an abbreviated branch."
  }
}

variable "source_repository" {
  description = "Canonical GitHub repository identity of the reviewed source. Only this repository can produce a deployment identity."
  type        = string

  validation {
    condition     = var.source_repository == "f5-sales-demo/canada-topology"
    error_message = "source_repository must be exactly f5-sales-demo/canada-topology."
  }
}

variable "ssh_public_key" {
  description = "SSH public key MATERIAL (the key string). When empty, read from ssh_public_key_path. Passing material keeps plan tests hermetic."
  type        = string
  default     = ""
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file, read once at the root when ssh_public_key is empty."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "subscription_id" {
  description = "Azure subscription ID used by the azurerm provider."
  type        = string
  # Default = the <AZURE_SUBSCRIPTION_ID> subscription the lab was built in.
  default = "00000000-0000-0000-0000-000000000000"
}

variable "tags" {
  description = "Additional tags merged with the standard tags (component/environment/deployer/managed_by)."
  type        = map(string)
  default     = {}
}