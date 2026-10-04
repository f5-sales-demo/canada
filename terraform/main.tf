# Canadian graph extracted from the attributed Canada source.
module "ce_topology_ca" {
  count  = var.enable_azure && var.enable_canada ? 1 : 0
  source = "./modules/ce-topology"

  ce_count           = var.ca_ce_count
  region_short       = local.ca_region_short
  mgmt_subnet_prefix = var.ca_mgmt_subnet_prefix
  site_prefix        = local.ca_site_prefix
}

# Canada Hub: RG, VNet, and CE subnets; Route Server remains opt-in.
module "azure_hub_ca" {
  count  = var.enable_azure && var.enable_canada ? 1 : 0
  source = "./modules/azure-hub"


  resource_group_name        = local.ca_resource_group_name
  location                   = var.ca_location
  hub_cidr                   = var.ca_hub_cidr
  mgmt_subnet_prefix         = var.ca_mgmt_subnet_prefix
  external_subnet_prefix     = var.ca_external_subnet_prefix
  internal_subnet_prefix     = var.ca_internal_subnet_prefix
  route_server_subnet_prefix = var.ca_route_server_subnet_prefix
  route_server_name          = local.ca_route_server_name
  enable_route_server        = var.enable_bgp
  bastion_subnet_prefix      = var.ca_bastion_subnet_prefix
  enable_bastion             = var.enable_bastion
  bastion_name               = local.ca_bastion_name
  tags                       = local.tags
}

# One Canadian CE VM (3 NICs + identity) per node.
module "ce_node_ca" {
  for_each = try(module.ce_topology_ca[0].ce_nodes, {})
  source   = "./modules/ce-node"

  hostname            = each.value.hostname
  resource_group_name = try(module.azure_hub_ca[0].resource_group_name, null)
  location            = try(module.azure_hub_ca[0].location, null)
  zone                = each.value.az
  vm_size             = var.ce_vm_size
  mgmt_subnet_id      = try(module.azure_hub_ca[0].management_subnet_id, null)
  external_subnet_id  = try(module.azure_hub_ca[0].external_subnet_id, null)
  internal_subnet_id  = try(module.azure_hub_ca[0].internal_subnet_id, null)
  mgmt_private_ip     = each.value.slo_ip
  admin_username      = var.admin_username
  ssh_public_key      = local.ssh_public_key

  custom_data = base64encode(local.ca_ce_cloud_init[each.key])

  tags = local.tags
}

resource "random_password" "site_console_admin_ca" {
  for_each = try(module.ce_topology_ca[0].ce_nodes, {})

  length           = 32
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "!#%*+-=?@^_~"

  keepers = {
    ce_vm_instance_id = module.ce_vm_ca[each.key].vm_instance_id
  }
}

resource "azurerm_virtual_machine_extension" "site_console_password_ca" {
  for_each = try(module.ce_topology_ca[0].ce_nodes, {})

  name                       = "site-console-admin-password"
  virtual_machine_id         = module.ce_vm_ca[each.key].vm_id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    script = base64encode(<<-SCRIPT
      #!/usr/bin/env bash
      set -euo pipefail
      password_b64='${base64encode(random_password.site_console_admin_ca[each.key].result)}'
      password=$(printf '%s' "$password_b64" | base64 --decode)
      printf 'admin:%s\n' "$password" | chpasswd
      unset password password_b64
    SCRIPT
    )
  })
}

# Canadian XC SMSv2 site + BGP object per node.
module "xc_site_ca" {
  for_each = try(module.ce_topology_ca[0].ce_nodes, {})
  source   = "./modules/xc-site"

  create_site                = true
  site_name                  = each.value.site_name
  hostname                   = each.value.hostname
  interface_name             = each.value.interface_name
  bind_registered_interfaces = var.azure_site_configuration_phase == "configured"
  mgmt_nic_mac               = var.azure_site_configuration_phase == "configured" ? module.ce_node_ca[each.key].mgmt_nic_mac : null
  inside_nic_mac             = var.azure_site_configuration_phase == "configured" ? module.ce_node_ca[each.key].inside_nic_mac : null
  external_nic_mac           = var.azure_site_configuration_phase == "configured" ? module.ce_node_ca[each.key].external_nic_mac : null
  ce_generation_id           = module.ce_node_ca[each.key].generation_id
  peer_ips                   = try(module.azure_frr_ca[0].peer_ips, [])
  ce_asn                     = var.ce_asn
  peer_asn                   = var.azure_frr_asn
  os_version                 = var.ce_os_version
  sw_version                 = var.ce_sw_version
  enable_bgp                 = var.enable_bgp
  approve_registration       = var.approve_registration && var.azure_site_configuration_phase == "configured"
  labels                     = local.ca_xc_labels
}

module "azure_frr_ca" {
  count  = var.enable_azure && var.enable_canada && var.enable_bgp ? 1 : 0
  source = "./modules/azure-frr"

  name                = "${var.component}-ca"
  location            = module.azure_hub_ca[0].location
  resource_group_name = module.azure_hub_ca[0].resource_group_name
  mgmt_subnet_id      = module.azure_hub_ca[0].management_subnet_id
  mgmt_subnet_prefix  = var.ca_mgmt_subnet_prefix
  route_server_id     = module.azure_hub_ca[0].route_server_id
  rs_peer_ips         = module.azure_hub_ca[0].rs_peer_ips
  ce_ips              = [for key in sort(keys(module.ce_topology_ca[0].ce_nodes)) : module.ce_node_ca[key].mgmt_private_ip]
  vip                 = var.ca_vip
  ce_asn              = var.ce_asn
  frr_asn             = var.azure_frr_asn
  rs_asn              = var.rs_asn
  admin_username      = var.admin_username
  ssh_public_key      = local.ssh_public_key
  tags                = local.tags
}

module "client_vm_ca" {
  count  = var.enable_azure && var.enable_canada ? 1 : 0
  source = "./modules/client-vm"

  name                = local.ca_client_vm_name
  resource_group_name = try(module.azure_hub_ca[0].resource_group_name, null)
  location            = try(module.azure_hub_ca[0].location, null)
  subnet_id           = try(module.azure_hub_ca[0].internal_subnet_id, null)
  admin_username      = var.admin_username
  ssh_public_key      = local.ssh_public_key
  tags                = local.tags
}

# ---------------------------------------------------------
# F5 XC Virtual Sites (Canada RE & Canada CE)
# ---------------------------------------------------------

resource "xcsh_virtual_site" "canada_re" {
  count     = var.enable_azure && var.enable_canada ? 1 : 0
  name      = local.ca_re_vsite_name
  namespace = var.enable_canada_public_re && var.ca_re_public_ip != null ? var.ca_re_public_ip.namespace : xcsh_namespace.canada.name
  labels    = local.ca_xc_labels

  site_type = "REGIONAL_EDGE"
  site_selector {
    expressions = ["ves.io/region in (${join(", ", [for city in var.ca_re_cities : "ves-io-${city}"])})"]
  }
}

resource "xcsh_virtual_site" "canada_ce" {
  count     = var.enable_azure && var.enable_canada ? 1 : 0
  name      = local.ca_ce_vsite_name
  namespace = xcsh_namespace.canada.name
  labels    = local.ca_xc_labels

  site_type = "CUSTOMER_EDGE"
  site_selector {
    expressions = ["canada-topology in (${local.ca_xc_labels["canada-topology"]})"]
  }
}

resource "xcsh_origin_pool" "canada" {
  count       = var.enable_azure && var.enable_canada ? 1 : 0
  name        = local.ca_origin_pool_name
  namespace   = xcsh_namespace.canada.name
  description = "Canadian origin pool discovered exclusively through Canadian CEs"
  labels      = local.ca_xc_labels

  port = var.origin_port

  origin_servers {
    labels = {}
    private_ip {
      ip              = local.selected_ca_origin_ip
      outside_network = {}
      site_locator {
        virtual_site {
          name      = xcsh_virtual_site.canada_ce[0].name
          namespace = xcsh_namespace.canada.name
        }
      }
    }
  }

  no_tls                 = {}
  loadbalancer_algorithm = "ROUND_ROBIN"
  endpoint_selection     = "DISTRIBUTED"
}

resource "xcsh_public_ip_binding" "canada" {
  count = var.enable_azure && var.enable_canada && var.enable_canada_public_re && var.ca_re_public_ip != null ? 1 : 0

  name                   = var.ca_re_public_ip.name
  namespace              = var.ca_re_public_ip.namespace
  expected_ip            = var.ca_re_public_ip.ip
  virtual_site           = xcsh_virtual_site.canada_re[0].name
  virtual_site_namespace = xcsh_virtual_site.canada_re[0].namespace
}

resource "terraform_data" "canada_public_ip_gate" {
  count = var.enable_azure && var.enable_canada && var.enable_canada_public_re ? 1 : 0
  input = var.ca_re_public_ip
  lifecycle {
    precondition {
      condition     = var.ca_re_public_ip != null
      error_message = "Canadian public RE advertisement requires a dedicated ca_re_public_ip allocation."
    }
  }
}

resource "xcsh_http_loadbalancer" "canada" {
  count      = var.enable_azure && var.enable_canada && var.enable_canada_public_re ? 1 : 0
  depends_on = [module.xc_site_ca, xcsh_virtual_site.canada_re, xcsh_virtual_site.canada_ce, terraform_data.canada_public_ip_gate]

  name         = local.ca_lb_name
  namespace    = xcsh_namespace.canada.name
  description  = "Canada-only public application through Toronto and Montreal Regional Edges."
  labels       = local.ca_xc_labels
  add_location = var.enable_canada_public_re

  domains = [local.ca_lb_domain]

  http {
    dns_volterra_managed = false
    port                 = 80
  }

  advertise_custom {
    dynamic "advertise_where" {
      for_each = var.enable_canada_public_re ? [1] : []
      content {
        advertise_on_public {
          public_ip {
            name      = try(xcsh_public_ip_binding.canada[0].name, "")
            namespace = try(xcsh_public_ip_binding.canada[0].namespace, "")
          }
        }
        use_default_port = {}
      }
    }


  }

  default_route_pools {
    pool {
      namespace = xcsh_namespace.canada.name
      name      = try(xcsh_origin_pool.canada[0].name, null)
    }
    weight   = 1
    priority = 1
  }

  round_robin            = {}
  no_challenge           = {}
  user_id_client_ip      = {}
  disable_waf            = {}
  disable_rate_limit     = {}
  disable_api_discovery  = {}
  disable_api_testing    = {}
  disable_api_definition = {}
  l7_ddos_protection {}
  active_service_policies {
    policies {
      name      = xcsh_service_policy.canada_only[0].name
      namespace = xcsh_namespace.canada.name
    }
  }
  disable_trust_client_ip_headers  = {}
  disable_malicious_user_detection = {}
  disable_malware_protection       = {}
  disable_threat_mesh              = {}
  default_sensitive_data_policy    = {}
}


resource "xcsh_http_loadbalancer" "internal" {
  count      = var.enable_azure && var.enable_canada ? 1 : 0
  depends_on = [module.xc_site_ca, xcsh_virtual_site.canada_re, xcsh_virtual_site.canada_ce, terraform_data.canada_public_ip_gate]

  name         = "${local.ca_lb_name}-internal"
  namespace    = xcsh_namespace.canada.name
  description  = "Internal Canadian BGP, primary-IP and ILB diagnostics."
  labels       = local.ca_xc_labels
  add_location = false

  domains = ["internal.canada.f5-sales-demo.ca"]

  http {
    dns_volterra_managed = false
    port                 = 80
  }

  advertise_custom {
    dynamic "advertise_where" {
      for_each = try(module.ce_topology_ca[0].ce_nodes, {})
      content {
        site {
          network = "SITE_NETWORK_OUTSIDE"
          site {
            namespace = "system"
            name      = advertise_where.value.site_name
          }
          ip = var.ca_vip
        }
        use_default_port = {}
      }
    }

    dynamic "advertise_where" {
      for_each = try(module.ce_topology_ca[0].ce_nodes, {})
      content {
        site {
          network = "SITE_NETWORK_OUTSIDE"
          site {
            namespace = "system"
            name      = advertise_where.value.site_name
          }
          ip = advertise_where.value.slo_ip
        }
        use_default_port = {}
      }
    }
    dynamic "advertise_where" {
      for_each = var.enable_canada_ilb ? [1] : []
      content {
        port = 80
        virtual_site_with_vip {
          ip      = cidrhost(var.ca_internal_subnet_prefix, 10)
          network = "SITE_NETWORK_SPECIFIED_VIP_INSIDE"
          virtual_site {
            name      = xcsh_virtual_site.canada_ce[0].name
            namespace = xcsh_namespace.canada.name
          }
        }
      }
    }
  }

  default_route_pools {
    pool {
      namespace = xcsh_namespace.canada.name
      name      = try(xcsh_origin_pool.canada[0].name, null)
    }
    weight   = 1
    priority = 1
  }

  round_robin            = {}
  no_challenge           = {}
  user_id_client_ip      = {}
  disable_waf            = {}
  disable_rate_limit     = {}
  disable_api_discovery  = {}
  disable_api_testing    = {}
  disable_api_definition = {}
  l7_ddos_protection {}
  no_service_policies              = {}
  disable_trust_client_ip_headers  = {}
  disable_malicious_user_detection = {}
  disable_malware_protection       = {}
  disable_threat_mesh              = {}
  default_sensitive_data_policy    = {}
}


module "ce_vm_ca" {
  source              = "./modules/ce-vm"
  for_each            = try(module.ce_topology_ca[0].ce_nodes, {})
  hostname            = each.value.hostname
  resource_group_name = module.azure_hub_ca[0].resource_group_name
  location            = module.azure_hub_ca[0].location
  zone                = each.value.az
  vm_size             = var.ce_vm_size
  admin_username      = var.admin_username
  ssh_public_key      = local.ssh_public_key
  custom_data         = base64encode(local.ca_ce_cloud_init[each.key])
  network             = module.ce_node_ca[each.key].network
  tags                = local.tags
  depends_on          = [module.xc_site_ca]
}

resource "xcsh_namespace" "canada" {
  name   = "canada"
  labels = local.ca_xc_labels
  lifecycle {
    create_before_destroy = true
  }
}

resource "xcsh_token" "ce" {
  count       = var.enable_canada ? 1 : 0
  name        = "canada-topology-registration"
  namespace   = "system"
  description = "Canada dedicated CE registration token"
  labels      = { for key, value in local.ca_xc_labels : key => value if key != "canada-source-commit" }
  type        = 0
}

resource "terraform_data" "deployment_guard" {
  input = { commit = var.source_commit_sha, tenant = data.external.xc_env_tenant.result.tenant }
  lifecycle {
    precondition {
      condition     = !var.enable_canada || (var.enable_azure && var.ca_ce_count == 3)
      error_message = "Canada Topology requires exactly three Canadian CEs."
    }
    precondition {
      condition     = length(distinct(var.origin_developer_cidrs)) == 2
      error_message = "Supply both verified workstation egress /32s."
    }
    precondition {
      condition     = var.enable_showcase_origin || var.ca_origin_ip != null
      error_message = "An external Canadian origin must be supplied explicitly."
    }
    precondition {
      condition     = toset(var.ca_re_cities) == toset(["toronto", "montreal"])
      error_message = "Canadian advertisement requires Toronto and Montreal."
    }
    precondition {
      condition     = cidrhost(var.ca_hub_cidr, 0) != cidrhost(format("%s/%s", var.ca_vip, split("/", var.ca_hub_cidr)[1]), 0)
      error_message = "Canadian VIP must be outside the Canadian hub VNet."
    }
  }
}
data "external" "xc_env_tenant" {
  program = [format("%s/scripts/xc-env-tenant.sh", path.module)]
  lifecycle {
    postcondition {
      condition     = contains(["", var.expected_xc_tenant], self.result.tenant)
      error_message = "Ambient XC API URL does not match the expected deployment tenant."
    }
  }
}

resource "xcsh_service_policy" "canada_only" {
  count       = var.enable_azure && var.enable_canada ? 1 : 0
  name        = "${local.ca_lb_name}-canada-only"
  namespace   = xcsh_namespace.canada.name
  description = "Allow actual source IPv4 addresses classified by XC GeoIP as Canada; deny all others."
  labels      = local.ca_xc_labels
  any_server  = {}
  allow_list {
    country_list        = ["COUNTRY_CA"]
    default_action_deny = {}
  }
}
