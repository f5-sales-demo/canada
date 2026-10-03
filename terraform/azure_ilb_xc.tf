module "azure_ilb_application_ca" {
  count  = var.enable_azure && var.enable_canada && var.enable_canada_ilb ? 1 : 0
  source = "./modules/azure-ilb-app"

  name             = "${var.component}-ca-inside${local.deployment_name_suffix}"
  namespace        = xcsh_namespace.canada.name
  domain           = "ilb.${local.ca_lb_domain}"
  vip              = cidrhost(var.ca_internal_subnet_prefix, 10)
  origin_pool_name = xcsh_origin_pool.canada[0].name
  labels           = local.ca_xc_labels

  depends_on = [module.xc_site_ca]
}
