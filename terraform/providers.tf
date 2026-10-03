provider "xcsh" { api_url = local.xc_api_url }
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
provider "azuread" {}

provider "azapi" { subscription_id = var.subscription_id }
