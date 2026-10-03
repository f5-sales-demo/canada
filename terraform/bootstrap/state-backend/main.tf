resource "azurerm_resource_group" "state" {
  name     = "rg-canada-terraform-state"
  location = "canadacentral"
  tags     = { repository = "f5-sales-demo/canada-topology", purpose = "terraform-state" }
  lifecycle { prevent_destroy = true }
}
resource "azurerm_storage_account" "state" {
  name                              = var.storage_account_name
  resource_group_name               = azurerm_resource_group.state.name
  location                          = azurerm_resource_group.state.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  min_tls_version                   = "TLS1_2"
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
    ip_rules       = var.workstation_egress_ips
  }
  blob_properties {
    versioning_enabled = true
    delete_retention_policy { days = 30 }
    container_delete_retention_policy { days = 30 }
  }
  tags = azurerm_resource_group.state.tags
  lifecycle { prevent_destroy = true }
}
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
  lifecycle { prevent_destroy = true }
}
