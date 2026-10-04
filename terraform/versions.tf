terraform {
  # The automated showcase lifecycle and its test harness execute this exact
  # version on the authoritative Ubuntu host.
  required_version = "= 1.16.3"

  required_providers {
    azapi = { source = "Azure/azapi", version = "= 2.12.0" }
    xcsh = {
      source  = "f5-sales-demo/xcsh"
      version = "= 13.1.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
