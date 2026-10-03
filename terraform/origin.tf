data "xcsh_network_regional_edges" "origin" {
  count = var.enable_azure && var.enable_showcase_origin ? 1 : 0
}

data "xcsh_network_cdn" "origin" {
  count = var.enable_azure && var.enable_showcase_origin ? 1 : 0
}

resource "terraform_data" "origin_f5_acl_gate" {
  count = var.enable_azure && var.enable_showcase_origin ? 1 : 0
  input = local.origin_f5_cidrs
  lifecycle {
    precondition {
      condition = (length(local.origin_f5_cidrs) > 0 &&
        data.xcsh_network_regional_edges.origin[0].api_release_tag == "v9.0.2" &&
      data.xcsh_network_cdn.origin[0].api_release_tag == "v9.0.2")
      error_message = "Origin ingress requires nonempty F5 provider CIDRs from the pinned API release."
    }
  }
}

module "showcase_origin_ca" {
  count               = var.enable_azure && var.enable_canada && var.enable_showcase_origin ? 1 : 0
  source              = "./modules/client-vm"
  name                = "${var.component}-ca-origin${local.deployment_name_suffix}"
  resource_group_name = module.azure_hub_ca[0].resource_group_name
  location            = module.azure_hub_ca[0].location
  subnet_id           = module.azure_hub_ca[0].management_subnet_id
  # CE hosts use 4-6 and FRR uses 20-21 in this subnet.
  private_ip        = cidrhost(var.ca_mgmt_subnet_prefix, 30)
  admin_username    = var.admin_username
  ssh_public_key    = local.ssh_public_key
  serve_http        = true
  allow_ssh         = false
  restrict_ingress  = true
  http_source_cidrs = sort(distinct(concat(local.origin_f5_cidrs, local.ca_origin_demo_cidrs, var.origin_developer_cidrs)))
  tags              = local.tags
  depends_on        = [terraform_data.origin_f5_acl_gate]
  custom_data = base64encode(<<-EOF
    #cloud-config
    write_files:
      - path: /srv/canada-origin/index.html
        permissions: '0644'
        content: |
          canada-showcase-canada-origin
      - path: /etc/systemd/system/canada-origin.service
        permissions: '0644'
        content: |
          [Unit]
          Description=Ephemeral Canadian Canada showcase HTTP origin
          After=network-online.target
          [Service]
          ExecStart=/usr/bin/python3 -m http.server 80 --bind 0.0.0.0 --directory /srv/canada-origin
          Restart=always
          [Install]
          WantedBy=multi-user.target
    runcmd:
      - [systemctl, daemon-reload]
      - [systemctl, enable, --now, canada-origin]
    EOF
  )
}

output "ca_origin_ip" {
  description = "Canadian origin endpoint for Canadian load balancers and control probes."
  value       = var.enable_azure && var.enable_canada ? local.selected_ca_origin_ip : null
}

output "ca_origin_ingress_acl" {
  value = {
    f5_cidrs           = local.origin_f5_cidrs
    developer_cidrs    = var.origin_developer_cidrs
    owned_demo_cidrs   = local.ca_origin_demo_cidrs
    provider_version   = "12.4.0"
    all_regional_edges = true
  }
}
locals {
  origin_f5_cidrs = var.enable_showcase_origin ? sort(distinct(concat(
    data.xcsh_network_regional_edges.origin[0].cidr_blocks,
    data.xcsh_network_cdn.origin[0].cidr_blocks,
  ))) : []
  ca_origin_demo_cidrs = var.enable_canada && var.enable_showcase_origin ? [
    for ip in concat(
      [for node in module.ce_node_ca : node.mgmt_private_ip],
      [for node in module.ce_node_ca : node.mgmt_public_ip],
      [module.client_vm_ca[0].private_ip, module.client_vm_ca[0].public_ip],
    ) : "${ip}/32"
  ] : []
  selected_ca_origin_ip = var.enable_showcase_origin ? module.showcase_origin_ca[0].public_ip : var.ca_origin_ip
}
