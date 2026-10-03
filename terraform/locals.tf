locals {
  deployment_identity_schema = "canada-topology.deployment-identity/v1"

  source_branch = trimprefix(var.source_ref, "refs/heads/")

  source_ref_sha256 = sha256("${local.deployment_identity_schema}\u0000${var.source_repository}\u0000${var.source_ref}")

  source_branch_slug_raw = trim(replace(lower(local.source_branch), "/[^a-z0-9]+/", "-"), "-")

  source_branch_slug = local.source_branch_slug_raw != "" ? local.source_branch_slug_raw : "branch"

  deployment_is_production = var.source_ref == "refs/heads/main"

  deployment_environment_key = local.deployment_is_production ? "production" : "${trimsuffix(substr(local.source_branch_slug, 0, 19), "-")}-${substr(local.source_ref_sha256, 0, 12)}"

  deployment_name_suffix = local.deployment_is_production ? "" : "-${local.deployment_environment_key}"

  xc_api_url = "https://${var.expected_xc_tenant}.console.ves.volterra.io"

  deployer_from_name = (
    var.deployer == "" && length(data.azuread_user.current) > 0
    ? try(
      lower("${substr(data.azuread_user.current[0].given_name, 0, 1)}${data.azuread_user.current[0].surname}"),
      ""
    )
    : ""
  )

  deployer_from_mail = (
    var.deployer == "" && length(data.azuread_user.current) > 0 && local.deployer_from_name == ""
    ? try(
      lower(split("@", data.azuread_user.current[0].mail)[0]),
      ""
    )
    : ""
  )

  deployer_from_oid = var.deployer == "" && length(data.azuread_client_config.current) > 0 ? try(substr(sha1(data.azuread_client_config.current[0].object_id), 0, 8), "") : ""

  deployer_resolved = coalesce(
    var.deployer,
    local.deployer_from_name,
    local.deployer_from_mail,
    local.deployer_from_oid
  )

  deployer = replace(lower(local.deployer_resolved), "/[^a-z0-9]/", "")

  site_prefix_base = coalesce(var.site_prefix, "${var.component}-${var.smsv2_site_generation}")

  preview_site_prefix = "canada-${trimsuffix(substr(local.source_branch_slug, 0, 14), "-")}-${substr(local.source_ref_sha256, 0, 12)}"

  site_prefix = local.deployment_is_production ? local.site_prefix_base : local.preview_site_prefix

  ca_region_short = coalesce(var.ca_region_short, var.ca_location)

  ca_site_prefix_base = coalesce(var.ca_site_prefix, "${local.site_prefix_base}-ca")

  ca_site_prefix = local.deployment_is_production ? local.ca_site_prefix_base : "${local.site_prefix}-ca"

  ca_resource_group_name = "${coalesce(var.ca_resource_group_name, "rg-${var.component}-ca-${local.deployer}")}${local.deployment_name_suffix}"

  ca_route_server_name = "${coalesce(var.ca_route_server_name, "${var.component}-ca-rs")}${local.deployment_name_suffix}"

  ca_bastion_name = "${coalesce(var.ca_bastion_name, "${var.component}-ca-bastion")}${local.deployment_name_suffix}"

  ca_client_vm_name = "${coalesce(var.ca_client_vm_name, "${var.component}-ca-client")}${local.deployment_name_suffix}"

  ca_origin_pool_name = "${coalesce(var.ca_origin_pool_name, "${var.component}-ca-pool")}${local.deployment_name_suffix}"

  ca_lb_name = "${coalesce(var.ca_lb_name, "${var.component}-ca-f5se")}${local.deployment_name_suffix}"

  ca_re_vsite_name = "${coalesce(var.ca_re_vsite_name, "${var.component}-ca-re-vsite")}${local.deployment_name_suffix}"

  ca_ce_vsite_name = "${coalesce(var.ca_ce_vsite_name, "${var.component}-ca-ce-vsite")}${local.deployment_name_suffix}"

  ca_lb_domain = local.deployment_is_production ? var.ca_lb_domain : "${local.deployment_environment_key}.${var.ca_lb_domain}"

  standard_tags = {
    component                = var.component
    environment              = var.environment
    deployer                 = local.deployer
    managed_by               = "terraform"
    canada_environment       = local.deployment_environment_key
    canada_repository        = "canada-topology"
    canada_source_ref_sha256 = local.source_ref_sha256
    canada_source_commit     = var.source_commit_sha
    canada_owner_id          = var.deployment_owner_id
    canada_actor_id          = var.deployment_actor_id
  }

  tags = merge(var.tags, local.standard_tags)

  xc_provenance_labels = {
    "canada-deployment-generation" = var.smsv2_site_generation
    "canada-environment"           = local.deployment_environment_key
    "canada-source-ref-sha256"     = substr(local.source_ref_sha256, 0, 32)
    "canada-source-commit"         = var.source_commit_sha
    "canada-owner-id"              = var.deployment_owner_id
    "canada-actor-id"              = var.deployment_actor_id
    "canada-xc-tenant"             = var.expected_xc_tenant
  }

  ca_xc_labels = merge(local.xc_provenance_labels, {
    "canada-topology" = "${local.ca_site_prefix}-azure"
  })

  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : file(pathexpand(var.ssh_public_key_path))

  ce_registration_token = var.registration_token != "" ? var.registration_token : try(xcsh_token.ce[0].uid, null)

  ca_ce_cloud_init = {
    for key, node in try(module.ce_topology_ca[0].ce_nodes, {}) : key => templatefile("${path.module}/cloud-init/ce-node.yaml", {
      probe_routing_script = file("${path.module}/cloud-init/azure-probe-routing.sh")
      inside_subnet        = var.ca_internal_subnet_prefix
      cluster_name         = node.site_name
      token                = local.ce_registration_token
      ssh_public_key       = chomp(local.ssh_public_key)
    })
  }
}
