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
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/networkInterfaces/example-nic", mac_address = "52:54:00:10:00:11" }
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

run "canadian_ilb_plans_successfully" {
  command = plan

  variables {
    ca_ce_count = 3
  }

  assert {
    condition     = output.ca_ilb_frontend_ip == "10.200.3.10"
    error_message = "Canada ILB frontend private IP should be 10.200.3.10."
  }

  assert {
    condition     = length(azurerm_lb.ca_ilb) == 1
    error_message = "When enable_canada = true and enable_canada_ilb = true, exactly one Canadian ILB should be created."
  }

  assert {
    condition     = length(azurerm_lb_rule.ca_application) == 1 && length(azurerm_lb_rule.ca_console) == 1
    error_message = "Canadian ILB application and console rules should be created."
  }
}

run "canadian_ilb_disabled_plans_no_ilb_resources" {
  command = plan

  variables {
    enable_canada_ilb = false
  }

  assert {
    condition     = length(azurerm_lb.ca_ilb) == 0
    error_message = "When enable_canada_ilb = false, no Canadian ILB should be created."
  }

  assert {
    condition     = output.ca_ilb_id == null
    error_message = "When enable_canada_ilb = false, ca_ilb_id output must be null."
  }
}
