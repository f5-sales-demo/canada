# Test suite for Canadian Azure Internal Load Balancer (ILB) variant architecture.

mock_provider "azurerm" {
  mock_resource "azurerm_route_table" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/routeTables/example-rt" }
  }
  mock_resource "azurerm_lb_backend_address_pool" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/loadBalancers/example-lb/backendAddressPools/example-pool" }
  }
  mock_resource "azurerm_lb" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/loadBalancers/example-lb" }
  }
  mock_resource "azurerm_route_server" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/virtualHubs/example-rs" }
  }
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Compute/virtualMachines/example-vm" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/example-id" }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/networkSecurityGroups/example-nsg" }
  }
  mock_resource "azurerm_network_interface" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/networkInterfaces/example-nic", mac_address = "52:54:00:10:00:11", private_ip_address = "10.200.1.4" }
  }
  mock_resource "azurerm_public_ip" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/publicIPAddresses/example-ip", ip_address = "192.0.2.20" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/virtualNetworks/example-vnet/subnets/example-subnet" }
  }
}
mock_provider "azuread" {}
mock_provider "azapi" {}
mock_provider "xcsh" {}

variables {
  enable_azure           = true
  site_prefix            = null
  ca_site_prefix         = null
  ca_lb_name             = null
  ca_origin_pool_name    = null
  ca_route_server_name   = null
  ca_bastion_name        = null
  ca_client_vm_name      = null
  ca_region_short        = null
  ca_resource_group_name = null
  ca_lb_domain           = "canada.f5-sales-demo.ca"
  deployer               = "tester"
  ssh_public_key         = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzwDqvgRGHaZqbo57o/AxuuqRNPT9MqeYNYsK1Owh8l plan-test-only"
  enable_canada          = true
  enable_canada_ilb      = true
}


run "provider_f5_acl_and_both_developer_routes" {
  command = plan
  variables {
    enable_showcase_origin = true
    origin_developer_cidrs = ["198.51.100.10/32", "203.0.113.20/32"]
  }
  override_data {
    target = data.xcsh_network_regional_edges.origin[0]
    values = { cidr_blocks = ["192.0.2.0/25", "192.0.2.128/25"], api_release_tag = "v9.0.2" }
  }
  override_data {
    target = data.xcsh_network_cdn.origin[0]
    values = { cidr_blocks = ["192.0.2.0/25"], api_release_tag = "v9.0.2" }
  }
  assert {
    condition     = output.ca_origin_ingress_acl.f5_cidrs == tolist(["192.0.2.0/25", "192.0.2.128/25"]) && output.ca_origin_ingress_acl.developer_cidrs == tolist(["198.51.100.10/32", "203.0.113.20/32"])
    error_message = "The origin ACL must include every provider CIDR and both independent developer egress /32s."
  }
}
run "developer_wildcard_rejected" {
  command = plan
  variables { origin_developer_cidrs = ["0.0.0.0/0"] }
  expect_failures = [var.origin_developer_cidrs]
}


run "both_workstation_routes_required" {
  command = plan
  variables { origin_developer_cidrs = ["198.51.100.10/32"] }
  expect_failures = [terraform_data.deployment_guard]
}
run "canadian_placement_required" {
  command = plan
  variables { ca_location = "eastus" }
  expect_failures = [var.ca_location]
}
run "both_canadian_re_cities_required" {
  command = plan
  variables { ca_re_cities = ["toronto"] }
  expect_failures = [terraform_data.deployment_guard]
}

run "non_tenant_domain_rejected" {
  command = plan
  variables { ca_lb_domain = "canada.example.com" }
  expect_failures = [var.ca_lb_domain]
}
