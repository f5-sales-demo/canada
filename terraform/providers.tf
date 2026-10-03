provider "xcsh" { api_url = local.xc_api_url }
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
provider "azuread" {}
locals { azure_provider_enabled = var.enable_canada }

provider "azapi" { subscription_id = var.subscription_id }
