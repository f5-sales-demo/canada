output "canada_ilb_private_ip" {
  description = "Canadian ILB private address for supported CE Site Console health and traffic verification; null when disabled."
  value       = try(azurerm_lb.ca_ilb[0].frontend_ip_configuration[0].private_ip_address, null)
}

output "ca_resource_group_name" {
  description = "Canadian Azure resource group used for supported ILB verification."
  value       = try(module.azure_hub_ca[0].resource_group_name, null)
}

output "ca_client_vm_name" {
  description = "Canadian test client VM used to probe the Canadian ILB."
  value       = try(module.client_vm_ca[0].vm_name, null)
}

output "ca_xc_site_names" {
  description = "Per-CE Canadian XC site names."
  value       = { for k, m in module.xc_site_ca : k => m.site_name }
}

output "ca_ce_vm_names" {
  description = "Per-CE Canadian VM names used for Azure runtime and extension verification."
  value       = { for k, m in module.ce_vm_ca : k => m.vm_name }
}

output "ca_lb_domain" {
  description = "Domain served by the Canada HTTP load balancer."
  value       = local.ca_lb_domain
}

output "ca_re_virtual_site_name" {
  description = "Name of the Canadian Regional Edge virtual site."
  value       = try(xcsh_virtual_site.canada_re[0].name, null)
}

output "ca_ce_virtual_site_name" {
  description = "Name of the Canadian Customer Edge virtual site."
  value       = try(xcsh_virtual_site.canada_ce[0].name, null)
}

output "ca_loadbalancer_name" {
  description = "Name of the Canadian HTTP load balancer."
  value       = try(xcsh_http_loadbalancer.canada[0].name, null)
}

output "ca_origin_pool_name" {
  description = "Name of the Canadian origin pool."
  value       = try(xcsh_origin_pool.canada[0].name, null)
}

output "ca_vip" {
  description = "Canadian external HA VIP advertised through CE-to-FRR-to-Route-Server BGP. The inside ILB frontend is separate."
  value       = var.ca_vip
}

output "ca_ilb_id" {
  description = "Azure Internal Load Balancer ID for Canadian regional path."
  value       = try(azurerm_lb.ca_ilb[0].id, null)
}

output "ca_ilb_frontend_ip" {
  description = "Azure Internal Load Balancer frontend private IP for Canadian regional path."
  value       = try(azurerm_lb.ca_ilb[0].frontend_ip_configuration[0].private_ip_address, null)
}

output "ce_registration_token" {
  description = "Resolved Azure CE registration token fed to cloud-init, or null when Azure is disabled and no override is supplied."
  value       = local.ce_registration_token
  sensitive   = true
}

output "ce_egress_requirements" {
  description = "Explicit outbound DNS, NTP, and HTTPS checks derived from the release-pinned CE allowlists."
  value = {
    api_release_tag = data.xcsh_network_customer_edge_egress.secure_mesh_v2.api_release_tag
    dns = {
      direction    = "egress"
      protocols    = ["udp", "tcp"]
      port         = 53
      destinations = data.xcsh_network_customer_edge_defaults.system_services.dns_servers
    }
    ntp = {
      direction    = "egress"
      protocols    = ["udp"]
      port         = 123
      destinations = data.xcsh_network_customer_edge_defaults.system_services.ntp_servers
    }
    https = {
      direction    = "egress"
      protocols    = ["tcp"]
      port         = 443
      destinations = data.xcsh_network_customer_edge_egress.secure_mesh_v2.domains
    }
  }
}

output "canada_ilb_application_domain" {
  value = try(xcsh_http_loadbalancer.internal[0].domains[0], null)
}

output "canada_ilb_console_ip" {
  value = try(azurerm_lb.ca_ilb[0].frontend_ip_configuration[1].private_ip_address, null)
}

output "canada_frr_peer_ips" {
  value = try(module.azure_frr_ca[0].peer_ips, [])
}

output "canada_frr_vm_names" {
  value = try(module.azure_frr_ca[0].vm_names, [])
}

output "canada_route_server_name" {
  value = local.ca_route_server_name
}

output "canada_client_nic_name" {
  value = try(module.client_vm_ca[0].nic_name, null)
}

output "canada_ilb_name" {
  value = try(azurerm_lb.ca_ilb[0].name, null)
}

output "canada_ce_mgmt_private_ips" {
  value = { for key, node in module.ce_node_ca : key => node.mgmt_private_ip }
}

output "canada_ce_sli_private_ips" {
  value = { for key, node in module.ce_node_ca : key => node.sli_private_ip }
}

output "canada_route_server_peer_ips" {
  value = try(module.azure_hub_ca[0].rs_peer_ips, [])
}

output "azure_subscription_id" {
  value = var.subscription_id
}

output "azure_interface_contract" {
  description = "Verified Azure device roles used by bootstrap and MAC-binding phases."
  value       = local.azure_interface_contract
}

output "canada_public_re" {
  description = "Private Canadian public RE acceptance inputs; null when advertisement is disabled."
  sensitive   = true
  value = var.enable_azure && var.enable_canada && var.enable_canada_public_re ? {
    allocation            = var.ca_re_public_ip
    namespace             = xcsh_namespace.canada.name
    virtual_site          = xcsh_virtual_site.canada_re[0].name
    re_namespace          = xcsh_virtual_site.canada_re[0].namespace
    ce_virtual_site       = xcsh_virtual_site.canada_ce[0].name
    ce_sites              = [for site in module.xc_site_ca : site.site_name]
    loadbalancer          = xcsh_http_loadbalancer.canada[0].name
    service_policy        = xcsh_service_policy.canada_only[0].name
    internal_loadbalancer = xcsh_http_loadbalancer.internal[0].name
    pool                  = xcsh_origin_pool.canada[0].name
    domain                = local.ca_lb_domain
    origin_ip             = local.selected_ca_origin_ip
    expected_marker       = var.enable_showcase_origin ? "canada-showcase-canada-origin" : null
  } : null
}
output "ca_ce_vm_ids" {
  value = { for k, m in module.ce_vm_ca : k => m.vm_id }
}
output "ca_site_console_admin_passwords" {
  sensitive = true
  value     = { for k, password in random_password.site_console_admin_ca : k => password.result }
}
output "ca_bastion_name" { value = local.ca_bastion_name }
output "deployment_identity" {
  value = {
    repository    = var.source_repository
    source_ref    = var.source_ref
    source_commit = var.source_commit_sha
    owner         = var.deployment_owner_id
    actor         = var.deployment_actor_id
  }
}

output "canada_internal_application_domain" {
  value = try(xcsh_http_loadbalancer.internal[0].domains[0], null)
}
